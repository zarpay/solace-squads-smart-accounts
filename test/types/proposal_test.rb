# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Proposal do
  let(:klass) { Solace::SquadsSmartAccounts::Proposal }
  let(:codecs) { Solace::Utils::Codecs }

  let(:settings) { Solace::Keypair.generate.address }
  let(:rent_collector) { Solace::Keypair.generate.address }
  let(:approver) { Solace::Keypair.generate.address }
  let(:rejecter) { Solace::Keypair.generate.address }

  # Builds raw Borsh account bytes for a Proposal: discriminator + fields, with
  # the status as a u8 variant + (for all but :executing) an i64 timestamp.
  def encode_proposal(status_variant:, timestamp:, approved:, rejected:, cancelled:)
    status_bytes  = [status_variant]
    status_bytes += codecs.encode_le_i64(timestamp).bytes unless timestamp.nil?

    bytes =
      [0, 0, 0, 0, 0, 0, 0, 0] + # 8-byte discriminator
      codecs.encode_pubkey(settings) +
      codecs.encode_le_u64(7).bytes +
      codecs.encode_pubkey(rent_collector) +
      status_bytes +
      [254] + # bump
      codecs.encode_vec_pubkeys(approved) +
      codecs.encode_vec_pubkeys(rejected) +
      codecs.encode_vec_pubkeys(cancelled)

    StringIO.new(bytes.pack('C*'))
  end

  it 'deserializes a draft proposal with no votes' do
    io = encode_proposal(status_variant: 0, timestamp: 1_700_000_000, approved: [], rejected: [], cancelled: [])

    proposal = klass.deserialize(io)

    assert_equal settings, proposal.settings
    assert_equal 7, proposal.transaction_index
    assert_equal rent_collector, proposal.rent_collector
    assert_equal :draft, proposal.status
    assert_equal 1_700_000_000, proposal.status_timestamp
    assert_equal 254, proposal.bump
    assert_empty proposal.approved
    assert_empty proposal.rejected
    assert_empty proposal.cancelled
  end

  it 'deserializes an approved proposal with an approval vote' do
    io = encode_proposal(status_variant: 3, timestamp: 1_700_000_500, approved: [approver], rejected: [], cancelled: [])

    proposal = klass.deserialize(io)

    assert_equal :approved, proposal.status
    assert_equal 1_700_000_500, proposal.status_timestamp
    assert_equal [approver], proposal.approved
  end

  it 'deserializes a rejected proposal with a rejection vote' do
    io = encode_proposal(status_variant: 2, timestamp: 1_700_000_900, approved: [], rejected: [rejecter], cancelled: [])

    proposal = klass.deserialize(io)

    assert_equal :rejected, proposal.status
    assert_equal [rejecter], proposal.rejected
  end

  it 'deserializes the unit-only executing variant without a timestamp' do
    io = encode_proposal(status_variant: 4, timestamp: nil, approved: [], rejected: [], cancelled: [])

    proposal = klass.deserialize(io)

    assert_equal :executing, proposal.status
    assert_nil proposal.status_timestamp
  end

  it 'raises on an unknown status variant' do
    io = encode_proposal(status_variant: 9, timestamp: nil, approved: [], rejected: [], cancelled: [])

    assert_raises(RuntimeError) { klass.deserialize(io) }
  end
end

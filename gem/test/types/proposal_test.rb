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

    klass.deserialize(StringIO.new(bytes.pack('C*')))
  end

  describe 'a draft proposal with no votes' do
    let(:proposal) do
      encode_proposal(status_variant: 0, timestamp: 1_700_000_000, approved: [], rejected: [], cancelled: [])
    end

    it 'decodes the settings' do
      assert_equal settings, proposal.settings
    end

    it 'decodes the transaction index' do
      assert_equal 7, proposal.transaction_index
    end

    it 'decodes the rent collector' do
      assert_equal rent_collector, proposal.rent_collector
    end

    it 'decodes the status as draft' do
      assert_equal :draft, proposal.status
    end

    it 'decodes the status timestamp' do
      assert_equal 1_700_000_000, proposal.status_timestamp
    end

    it 'decodes the bump' do
      assert_equal 254, proposal.bump
    end

    it 'has no approvals' do
      assert_empty proposal.approved
    end

    it 'has no rejections' do
      assert_empty proposal.rejected
    end

    it 'has no cancellations' do
      assert_empty proposal.cancelled
    end
  end

  describe 'an approved proposal with an approval vote' do
    let(:proposal) do
      encode_proposal(status_variant: 3, timestamp: 1_700_000_500, approved: [approver], rejected: [], cancelled: [])
    end

    it 'decodes the status as approved' do
      assert_equal :approved, proposal.status
    end

    it 'decodes the status timestamp' do
      assert_equal 1_700_000_500, proposal.status_timestamp
    end

    it 'records the approver' do
      assert_equal [approver], proposal.approved
    end
  end

  describe 'a rejected proposal with a rejection vote' do
    let(:proposal) do
      encode_proposal(status_variant: 2, timestamp: 1_700_000_900, approved: [], rejected: [rejecter], cancelled: [])
    end

    it 'decodes the status as rejected' do
      assert_equal :rejected, proposal.status
    end

    it 'records the rejecter' do
      assert_equal [rejecter], proposal.rejected
    end
  end

  describe 'the unit-only executing variant' do
    let(:proposal) do
      encode_proposal(status_variant: 4, timestamp: nil, approved: [], rejected: [], cancelled: [])
    end

    it 'decodes the status as executing' do
      assert_equal :executing, proposal.status
    end

    it 'has no status timestamp' do
      assert_nil proposal.status_timestamp
    end
  end

  describe 'an unknown status variant' do
    it 'raises' do
      assert_raises(RuntimeError) do
        encode_proposal(status_variant: 9, timestamp: nil, approved: [], rejected: [], cancelled: [])
      end
    end
  end
end

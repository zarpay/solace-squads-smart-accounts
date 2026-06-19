# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::LogEventArgsV2 do
  let(:klass) { Solace::SquadsSmartAccounts::LogEventArgsV2 }
  let(:codecs) { Solace::Utils::Codecs }

  # Borsh-encoded inner event: a 1-byte SmartAccountEvent tag + a 32-byte pubkey.
  let(:settings) { Solace::Keypair.generate.address }
  let(:event_bytes) { [0] + codecs.encode_pubkey(settings) }

  # Raw LogEventArgsV2 bytes (no logEvent discriminator — the Program layer strips
  # it): a single Borsh `event: bytes` field (u32 length prefix + bytes).
  let(:bytes) { codecs.encode_bytes(event_bytes) }

  let(:args) { klass.deserialize(StringIO.new(bytes.pack('C*'))) }

  it 'decodes the inner event bytes' do
    assert_equal event_bytes.pack('C*'), args.event
  end
end

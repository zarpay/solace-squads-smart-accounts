# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::CreateSmartAccountEvent do
  let(:klass) { Solace::SquadsSmartAccounts::CreateSmartAccountEvent }
  let(:codecs) { Solace::Utils::Codecs }

  let(:settings) { Solace::Keypair.generate.address }

  # Borsh-encoded SmartAccountEvent: a 1-byte enum variant tag (skipped during
  # decode) followed by CreateSmartAccountEvent.new_settings_pubkey.
  let(:bytes) { [5] + codecs.encode_pubkey(settings) }

  let(:event) { klass.deserialize(StringIO.new(bytes.pack('C*'))) }

  it 'decodes the new settings pubkey after skipping the enum tag' do
    assert_equal settings, event.new_settings_pubkey
  end
end

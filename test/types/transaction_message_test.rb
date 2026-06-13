# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::TransactionMessage do
  let(:klass) { Solace::SquadsSmartAccounts::TransactionMessage }

  let(:vault) { Solace::Keypair.generate }
  let(:recipient) { Solace::Keypair.generate }
  let(:system_program) { Solace::Constants::SYSTEM_PROGRAM_ID }

  # One compiled inner instruction: SystemProgram transfer, account_keys indices.
  let(:instruction) do
    Solace::Instruction.new.tap do |ix|
      ix.program_index = 2
      ix.accounts      = [0, 1]
      ix.data          = [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    end
  end

  let(:tx_message) do
    klass.new(
      num_signers:              1,
      num_writable_signers:     1,
      num_writable_non_signers: 1,
      account_keys:             [vault.address, recipient.address, system_program],
      instructions:             [instruction]
    )
  end

  describe '#serialize' do
    let(:bytes) { tx_message.serialize }

    it 'begins with the three header counts' do
      assert_equal [1, 1, 1], bytes[0, 3]
    end

    it 'serializes account_keys as a u8-count SmallVec of 32-byte pubkeys' do
      assert_equal 3, bytes[3]
      assert_equal Solace::Utils::Codecs.base58_to_bytes(vault.address), bytes[4, 32]
      assert_equal Solace::Utils::Codecs.base58_to_bytes(recipient.address), bytes[36, 32]
      assert_equal Solace::Utils::Codecs.base58_to_bytes(system_program), bytes[68, 32]
    end

    it 'appends the compiled instructions after the account keys' do
      expected = Solace::Utils::Codecs.encode_compiled_instructions([instruction])

      assert_equal expected, bytes[100, expected.length]
    end

    it 'ends with an empty address-table-lookups SmallVec' do
      assert_equal 0, bytes.last
    end
  end
end

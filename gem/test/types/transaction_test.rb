# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Transaction do
  let(:klass) { Solace::SquadsSmartAccounts::Transaction }

  let(:vault) { Solace::Keypair.generate.address }
  let(:recipient) { Solace::Keypair.generate.address }
  let(:cosigner) { Solace::Keypair.generate.address }
  let(:system_program) { Solace::Constants::SYSTEM_PROGRAM_ID }

  describe '#account_metas' do
    it 'derives flags for a single-signer vault transfer' do
      transaction = klass.new(
        settings:                 Solace::Keypair.generate.address,
        creator:                  Solace::Keypair.generate.address,
        rent_collector:           Solace::Keypair.generate.address,
        index:                    1,
        account_index:            0,
        num_signers:              1,
        num_writable_signers:     1,
        num_writable_non_signers: 1,
        account_keys:             [vault, recipient, system_program]
      )

      assert_equal(
        [
          { pubkey: vault, signer: true, writable: true },
          { pubkey: recipient, signer: false, writable: true },
          { pubkey: system_program, signer: false, writable: false }
        ],
        transaction.account_metas
      )
    end

    it 'marks a readonly signer as a non-writable signer' do
      transaction = klass.new(
        settings:                 Solace::Keypair.generate.address,
        creator:                  Solace::Keypair.generate.address,
        rent_collector:           Solace::Keypair.generate.address,
        index:                    1,
        account_index:            0,
        num_signers:              2,
        num_writable_signers:     1,
        num_writable_non_signers: 1,
        account_keys:             [vault, cosigner, recipient, system_program]
      )

      assert_equal(
        [
          { pubkey: vault, signer: true, writable: true },
          { pubkey: cosigner, signer: true, writable: false },
          { pubkey: recipient, signer: false, writable: true },
          { pubkey: system_program, signer: false, writable: false }
        ],
        transaction.account_metas
      )
    end
  end
end

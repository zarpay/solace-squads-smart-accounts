# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `addSpendingLimitAsAuthority` instruction for the Squads
      # Smart Account program.
      #
      # Creates a SpendingLimit PDA granting designated signers a pre-authorized
      # allowance from a vault. Only callable by the account's settings
      # authority — no consensus involved.
      #
      # IDL accounts (in order):
      #   0. settings          — readonly, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. spendingLimit     — writable, non-signer (PDA to be created)
      #   3. rentPayer         — writable, signer (funds the new account's rent)
      #   4. systemProgram     — readonly, non-signer
      #   5. program           — readonly, non-signer
      class AddSpendingLimitAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:add_spending_limit_as_authority")[0..7]
        DISCRIMINATOR = [169, 189, 84, 54, 30, 244, 223, 212].freeze

        # Builds a {Solace::Instruction} for addSpendingLimitAsAuthority.
        #
        # @param seed [#to_s] Arbitrary pubkey seeding the SpendingLimit PDA.
        # @param account_index [Integer] Vault index the limit spends from.
        # @param mint [#to_s] Token mint; DEFAULT_PUBKEY for SOL.
        # @param amount [Integer] Amount spendable per period (mint decimals).
        # @param period [Integer] Period enum value (reset cadence).
        # @param signers [Array<#to_s>] Pubkeys allowed to use the limit.
        # @param destinations [Array<#to_s>] Allowed destinations; empty = any.
        # @param expiration [Integer] Unix expiration timestamp; I64_MAX = never.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the settings authority.
        # @param spending_limit_index [Integer] Account index of the SpendingLimit PDA.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          seed:,
          account_index:,
          mint:,
          amount:,
          period:,
          signers:,
          destinations:,
          expiration:,
          memo:,
          settings_index:,
          settings_authority_index:,
          spending_limit_index:,
          rent_payer_index:,
          system_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              settings_authority_index,
              spending_limit_index,
              rent_payer_index,
              system_program_index,
              program_index
            ]

            ix.data = data(
              seed:,
              account_index:,
              mint:,
              amount:,
              period:,
              signers:,
              destinations:,
              expiration:,
              memo:
            )
          end
        end

        # Encodes the `AddSpendingLimitArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(
          seed:,
          account_index:,
          mint:,
          amount:,
          period:,
          signers:,
          destinations:,
          expiration:,
          memo:
        )
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_pubkey(seed) +
            [account_index] +
            Solace::Utils::Codecs.encode_pubkey(mint) +
            Solace::Utils::Codecs.encode_le_u64(amount).bytes +
            [period] +
            Solace::Utils::Codecs.encode_vec_pubkeys(signers) +
            Solace::Utils::Codecs.encode_vec_pubkeys(destinations) +
            Solace::Utils::Codecs.encode_le_i64(expiration).bytes +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end

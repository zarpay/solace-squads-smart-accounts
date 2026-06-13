# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `useSpendingLimit` instruction for the Squads Smart Account program.
      #
      # Transfers funds from a vault to a destination within a pre-authorized
      # spending limit — single signature from an allowed signer, no consensus.
      #
      # IDL accounts (in order):
      #   0. settings                 — readonly, non-signer
      #   1. signer                   — readonly, signer (must be allowed by the limit)
      #   2. spendingLimit            — writable, non-signer
      #   3. smartAccount             — writable, non-signer (vault to transfer from)
      #   4. destination              — writable, non-signer
      #   5. systemProgram            — readonly, optional (required for SOL limits)
      #   6. mint                     — readonly, optional (SPL limits only)
      #   7. smartAccountTokenAccount — writable, optional (SPL limits only)
      #   8. destinationTokenAccount  — writable, optional (SPL limits only)
      #   9. tokenProgram             — readonly, optional (SPL limits only)
      #  10. program                  — readonly, non-signer
      #
      # Absent optional accounts are signaled by passing the Squads program ID
      # in their slot (Anchor's optional-account convention). For SOL limits
      # the four SPL slots must all be the program ID.
      class UseSpendingLimitInstruction
        # 8-byte Anchor discriminator: SHA256("global:use_spending_limit")[0..7]
        DISCRIMINATOR = [41, 179, 70, 5, 194, 147, 239, 158].freeze

        # Builds a {Solace::Instruction} for useSpendingLimit.
        #
        # @param amount [Integer] Amount of tokens to transfer (mint decimals).
        # @param decimals [Integer] Decimals of the mint (9 for SOL) — order-of-magnitude check.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param signer_index [Integer] Account index of the allowed signer.
        # @param spending_limit_index [Integer] Account index of the SpendingLimit PDA.
        # @param smart_account_index [Integer] Account index of the vault.
        # @param destination_index [Integer] Account index of the destination.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param mint_index [Integer] Account index of the mint (program ID slot for SOL).
        # @param smart_account_token_account_index [Integer] Vault ATA index (program ID slot for SOL).
        # @param destination_token_account_index [Integer] Destination ATA index (program ID slot for SOL).
        # @param token_program_index [Integer] Token program index (program ID slot for SOL).
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          amount:,
          decimals:,
          memo:,
          settings_index:,
          signer_index:,
          spending_limit_index:,
          smart_account_index:,
          destination_index:,
          system_program_index:,
          mint_index:,
          smart_account_token_account_index:,
          destination_token_account_index:,
          token_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              signer_index,
              spending_limit_index,
              smart_account_index,
              destination_index,
              system_program_index,
              mint_index,
              smart_account_token_account_index,
              destination_token_account_index,
              token_program_index,
              program_index
            ]

            ix.data = data(amount:, decimals:, memo:)
          end
        end

        # Encodes the `UseSpendingLimitArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(amount:, decimals:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_le_u64(amount).bytes +
            [decimals] +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `createSmartAccount` instruction for the Squads Smart Account program.
      #
      # Creates a new smart account (multisig) on-chain. The resulting settings account
      # is a PDA derived from the creator's public key.
      #
      # IDL accounts (in order):
      #   0. programConfig  — writable, non-signer
      #   1. treasury       — writable, non-signer
      #   2. creator        — writable, signer
      #   3. systemProgram  — readonly, non-signer
      #   4. program        — readonly, non-signer
      #   5. settings       — writable, non-signer (remaining account — PDA to be created)
      class CreateSmartAccountInstruction
        # 8-byte Anchor discriminator: SHA256("global:create_smart_account")[0..7]
        DISCRIMINATOR = [197, 102, 253, 231, 77, 84, 50, 17].freeze

        # Builds a {Solace::Instruction} for createSmartAccount.
        #
        # @param settings_authority [String, nil] Base58 pubkey of the optional reconfiguration
        #   authority, or nil for autonomous smart accounts.
        # @param threshold [Integer] Number of approvals required to execute a transaction.
        # @param signers [Array<SmartAccountSigner>] Signers on the smart account.
        # @param time_lock [Integer] Seconds that must pass between proposal and execution.
        # @param rent_collector [String, nil] Base58 pubkey for reclaiming rent, or nil.
        # @param memo [String, nil] Optional indexing memo.
        # @param program_config_index [Integer] Account index of programConfig.
        # @param treasury_index [Integer] Account index of treasury.
        # @param creator_index [Integer] Account index of creator.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @param settings_index [Integer] Account index of the settings PDA to be created.
        # @return [Solace::Instruction]
        def self.build(
          settings_authority:,
          threshold:,
          signers:,
          time_lock:,
          rent_collector:,
          memo:,
          program_config_index:,
          treasury_index:,
          creator_index:,
          system_program_index:,
          program_index:,
          settings_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              program_config_index,
              treasury_index,
              creator_index,
              system_program_index,
              program_index,
              settings_index
            ]
            ix.data = data(
              settings_authority:,
              threshold:,
              signers:,
              time_lock:,
              rent_collector:,
              memo:
            )
          end
        end

        # Encodes the `CreateSmartAccountArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(settings_authority:, threshold:, signers:, time_lock:, rent_collector:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_option_pubkey(settings_authority) +
            Solace::Utils::Codecs.encode_le_u16(threshold).bytes +
            Solace::Utils::Codecs.encode_smart_account_signers(signers) +
            Solace::Utils::Codecs.encode_le_u32(time_lock).bytes +
            Solace::Utils::Codecs.encode_option_pubkey(rent_collector) +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end

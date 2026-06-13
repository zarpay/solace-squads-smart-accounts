# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object for the program's TransactionMessage — a compiled
    # inner transaction stored by `createTransaction` and replayed by
    # `executeTransaction`. It mirrors a Solana v0 message: account keys ordered
    # [writable signers, readonly signers, writable non-signers, readonly
    # non-signers] with the three header counts, plus compiled instructions.
    #
    # Address-table lookups are not supported yet and are always serialized as
    # an empty SmallVec.
    #
    # @example
    #   message = TransactionMessage.new(
    #     num_signers:              1,
    #     num_writable_signers:     1,
    #     num_writable_non_signers: 1,
    #     account_keys:             [vault, recipient, system_program],
    #     instructions:             [compiled_transfer]
    #   )
    #   message.serialize # => [Integer, ...]
    TransactionMessage = Data.define(
      :num_signers,              # Integer — total signer account keys
      :num_writable_signers,     # Integer — writable subset of the signers
      :num_writable_non_signers, # Integer — writable subset of the non-signers
      :account_keys,             # Array<String> — base58 keys in canonical order
      :instructions              # Array<Solace::Instruction> — compiled (indices into account_keys)
    ) do
      # Serializes the message in the Squads SmallVec format.
      #
      # @return [Array<Integer>] The serialized message bytes.
      def serialize
        [num_signers, num_writable_signers, num_writable_non_signers] +
          Solace::Utils::Codecs.encode_smallvec_u8_pubkeys(account_keys) +
          Solace::Utils::Codecs.encode_compiled_instructions(instructions) +
          [0] # address_table_lookups: empty SmallVec<u8, _>
      end
    end
  end
end

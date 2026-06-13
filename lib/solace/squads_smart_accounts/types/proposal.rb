# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object for a deserialized Proposal account — the vote
    # tracker created alongside a Transaction. A proposal collects approvals and
    # rejections; once approved (and past the settings time lock) the associated
    # Transaction may be executed.
    #
    # Layout (state/proposal.rs, matches the IDL):
    #   settings(32), transaction_index(u64), rent_collector(32),
    #   status(ProposalStatus: u8 variant + i64 timestamp — except the unit-only
    #   Executing variant, which carries no timestamp), bump(u8),
    #   approved(Vec<Pubkey>), rejected(Vec<Pubkey>), cancelled(Vec<Pubkey>).
    #
    # @example
    #   proposal = program.get_proposal(proposal_address: proposal_address)
    #   proposal.status   # => :approved
    #   proposal.approved # => ["9xQ...", ...]
    Proposal = Data.define(
      :settings,          # String  — base58 consensus (settings) account
      :transaction_index, # Integer — index of the associated transaction (u64)
      :rent_collector,    # String  — base58 rent collector
      :status,            # Symbol  — :draft, :active, :rejected, :approved, :executing, :executed, :cancelled
      :status_timestamp,  # Integer, nil — unix timestamp of the status change (nil for :executing)
      :bump,              # Integer — proposal PDA bump seed
      :approved,          # Array<String> — base58 pubkeys that approved
      :rejected,          # Array<String> — base58 pubkeys that rejected
      :cancelled          # Array<String> — base58 pubkeys that cancelled
    ) do
      class << self
        # ProposalStatus enum variants, in Borsh variant-index order. Every
        # variant wraps an i64 timestamp except the unit-only :executing (index 4).
        STATUSES = %i[draft active rejected approved executing executed cancelled].freeze

        # Deserializes a Proposal account from a stream of Borsh-encoded account data.
        #
        # @param io [IO, StringIO] Stream positioned at the start of the account data.
        # @return [Proposal] The deserialized, frozen value.
        # @raise [RuntimeError] If the status variant is unknown.
        def deserialize(io)
          io.read(8) # skip 8-byte Anchor discriminator

          settings                 = Solace::Utils::Codecs.decode_pubkey(io)
          transaction_index        = Solace::Utils::Codecs.decode_le_u64(io)
          rent_collector           = Solace::Utils::Codecs.decode_pubkey(io)
          status, status_timestamp = decode_status(io)
          bump                     = Solace::Utils::Codecs.decode_u8(io)
          approved                 = Solace::Utils::Codecs.decode_vec_pubkeys(io)
          rejected                 = Solace::Utils::Codecs.decode_vec_pubkeys(io)
          cancelled                = Solace::Utils::Codecs.decode_vec_pubkeys(io)

          new(
            settings:,
            transaction_index:,
            rent_collector:,
            status:,
            status_timestamp:,
            bump:,
            approved:,
            rejected:,
            cancelled:
          )
        end

        private

        # Decodes the ProposalStatus enum: a u8 variant index followed by an i64
        # timestamp for every variant except the unit-only Executing variant.
        #
        # @param io [IO, StringIO] The stream to read from.
        # @return [Array(Symbol, Integer), Array(Symbol, nil)] The status symbol and its timestamp.
        def decode_status(io)
          status    = status_symbol(Solace::Utils::Codecs.decode_u8(io))
          timestamp = status == :executing ? nil : Solace::Utils::Codecs.decode_le_i64(io)

          [status, timestamp]
        end

        # Maps a ProposalStatus variant index to its status symbol.
        #
        # @param variant [Integer] The Borsh enum variant index.
        # @return [Symbol] The status symbol.
        # @raise [RuntimeError] If the variant is not a known ProposalStatus.
        def status_symbol(variant)
          STATUSES[variant] || raise("Unknown ProposalStatus variant: #{variant}")
        end
      end
    end
  end
end

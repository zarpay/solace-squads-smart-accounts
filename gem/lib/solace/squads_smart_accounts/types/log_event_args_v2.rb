# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object for the arguments of the program's `logEvent`
    # instruction, the self-CPI through which the program records events. The
    # deployed program takes `LogEventArgsV2 { event: Vec<u8> }` — a single
    # Borsh-encoded `SmartAccountEvent`. (An older `LogEventArgs` form carrying
    # `account_seeds`/`bump` is dead code in the program and described by the
    # bundled IDL, but is never emitted.)
    #
    # Extracting the args bytestream from a landed transaction is the Program
    # layer's responsibility — see
    # Solace::Programs::SquadsSmartAccount#get_created_smart_account_event.
    #
    # @example
    #   args  = LogEventArgsV2.deserialize(io)
    #   event = CreateSmartAccountEvent.deserialize(StringIO.new(args.event))
    LogEventArgsV2 = Data.define(
      :event # String — Borsh-encoded SmartAccountEvent bytes (binary string)
    ) do
      # Deserializes a LogEventArgsV2 from a stream of Borsh-encoded instruction
      # data (positioned just past the 8-byte logEvent discriminator).
      #
      # @param io [IO, StringIO] Stream positioned at the start of the args.
      # @return [LogEventArgsV2] The deserialized, frozen args value.
      def self.deserialize(io)
        new(event: Solace::Utils::Codecs.decode_bytes(io))
      end
    end

    # 8-byte Anchor discriminator of the `logEvent` instruction (sha256("global:
    # log_event")[0, 8]), a stable name-derived instruction discriminator — not
    # per-event data. The Program layer uses it to locate the logEvent self-CPI
    # among a transaction's inner instructions. (Defined here rather than inside
    # the Data.define block, where constant assignment would leak to the enclosing
    # module instead of the class.)
    LogEventArgsV2::DISCRIMINATOR = [5, 9, 90, 141, 223, 134, 57, 217].freeze
  end
end

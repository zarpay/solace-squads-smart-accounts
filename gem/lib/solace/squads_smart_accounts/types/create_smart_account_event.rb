# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing the `CreateSmartAccountEvent` the program
    # emits when a smart account is created. It is the `CreateSmartAccountEvent`
    # variant of the Borsh `SmartAccountEvent` enum carried inside
    # {LogEventArgs#event}, so deserialization reads the 1-byte enum variant tag
    # before the event fields.
    #
    # On windowed creation the program picks one candidate settings PDA from the
    # offered window; this event is the only way to learn which one was chosen
    # (see Solace::Programs::SquadsSmartAccount#created_smart_account_settings).
    #
    # The on-chain event also carries `new_settings_content: Settings`, but only
    # `new_settings_pubkey` is decoded here — it is all the caller needs to derive
    # the vault, and the trailing Settings can be fetched on demand.
    #
    # @example
    #   event = CreateSmartAccountEvent.deserialize(StringIO.new(log_event_args.event))
    #   event.new_settings_pubkey # => base58 settings address
    CreateSmartAccountEvent = Data.define(
      :new_settings_pubkey # String — base58 address of the newly created settings account
    ) do
      # Deserializes a CreateSmartAccountEvent from a stream of Borsh-encoded
      # SmartAccountEvent bytes (positioned at the enum variant tag).
      #
      # @param io [IO, StringIO] Stream positioned at the start of the event.
      # @return [CreateSmartAccountEvent] The deserialized, frozen event value.
      def self.deserialize(io)
        Solace::Utils::Codecs.decode_u8(io) # SmartAccountEvent enum variant tag

        new(
          new_settings_pubkey: Solace::Utils::Codecs.decode_pubkey(io)
        )
      end
    end
  end
end

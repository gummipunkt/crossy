require "json"
require "securerandom"

module Posting
  class NostrClient < BaseClient
    DEFAULT_RELAYS = [
      "wss://relay.damus.io",
      "wss://relay.snort.social"
    ].freeze

    def prepare_event(post)
      content = post.content_text.to_s
      created_at = Time.now.to_i
      kind = 1 # text note
      tags = []
      pubkey = @provider_account.public_key.to_s
      raise "Missing public key" if pubkey.blank?

      event = { "kind" => kind, "content" => content, "created_at" => created_at, "tags" => tags, "pubkey" => pubkey }
      event["id"] = placeholder_event_id(event)
      event
    end

    def publish_signed_event!(event, relays: DEFAULT_RELAYS)
      # Lazy load WS-Client nur hier, damit prepare_event ohne Gem funktioniert
      require "websocket-client-simple"
      message = ["EVENT", event]
      payload = JSON.dump(message)

      last_ok = nil
      relays.each do |url|
        ws = WebSocket::Client::Simple.connect(url)
        done = false
        ws.on(:open) { ws.send(payload) }
        ws.on(:message) { |msg| last_ok = msg.data; done = true }
        ws.on(:error) { |_e| done = true }
        ws.on(:close) { done = true }

        # simple wait loop with timeout
        start = Time.now
        until done
          sleep 0.05
          break if Time.now - start > 3
        end
        ws.close
      end
      last_ok
    end

    private

    def placeholder_event_id(event)
      # clients sign und berechnen id; hier nur Platzhalter für UI/Flow
      SecureRandom.hex(32)
    end
  end
end



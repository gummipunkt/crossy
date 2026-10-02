require "digest"
require "json"
require "securerandom"

module Posting
  class NostrClient < BaseClient
    DEFAULT_RELAYS = [
      "wss://relay.damus.io",
      "wss://relay.snort.social"
    ].freeze
    RELAY_TIMEOUT = 5

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

    # Checks a browser-signed event before it is published for this post:
    # NIP-01 id, BIP-340 signature, the account's key and the post content.
    def verify_signed_event!(event, post)
      raise "Invalid Nostr event: id" unless hex?(event["id"], 64)
      raise "Invalid Nostr event: pubkey" unless hex?(event["pubkey"], 64)
      raise "Invalid Nostr event: sig" unless hex?(event["sig"], 128)
      raise "Nostr event must be a text note (kind 1)" unless event["kind"].to_i == 1
      raise "Nostr event content does not match the post" unless event["content"].to_s == post.content_text.to_s

      expected_pubkey = @provider_account.public_key.to_s.strip.downcase
      if hex?(expected_pubkey, 64) && event["pubkey"].downcase != expected_pubkey
        raise "Nostr event was signed with a different key than this account"
      end

      id = self.class.event_id(event)
      raise "Nostr event id does not match its content" unless id == event["id"].downcase

      valid = Nostr::Schnorr.valid?([ event["pubkey"] ].pack("H*"), [ id ].pack("H*"), [ event["sig"] ].pack("H*"))
      raise "Invalid Nostr signature" unless valid

      true
    end

    # NIP-01: sha256 over the compact JSON serialization of the event fields.
    def self.event_id(event)
      serialized = JSON.generate([
        0,
        event["pubkey"].to_s.downcase,
        event["created_at"].to_i,
        event["kind"].to_i,
        Array(event["tags"]),
        event["content"].to_s
      ])
      Digest::SHA256.hexdigest(serialized)
    end

    # Sends the event to every relay and returns the relays that accepted it.
    # Raises when none did, so the delivery is not reported as published.
    def publish_signed_event!(event, relays: DEFAULT_RELAYS)
      payload = JSON.generate([ "EVENT", event ])

      results = relays.to_h do |url|
        result =
          begin
            send_to_relay(url, payload, event["id"])
          rescue => e
            [ false, e.message ]
          end
        [ url, result ]
      end

      accepted = results.select { |_url, (ok, _message)| ok }.keys
      if accepted.empty?
        details = results.map { |url, (_ok, message)| "#{url}: #{message.presence || "rejected"}" }.join("; ")
        raise "No Nostr relay accepted the event (#{details})"
      end
      accepted
    end

    private

    # Returns [accepted, message] from the relay's NIP-01 ["OK", id, bool, msg] reply.
    def send_to_relay(url, payload, event_id)
      # Lazy load so prepare_event works without the WebSocket gem
      require "websocket-client-simple"

      result = nil
      ws = WebSocket::Client::Simple.connect(url)
      ws.on(:open) { ws.send(payload) }
      ws.on(:message) do |msg|
        data = (JSON.parse(msg.data) rescue nil)
        if data.is_a?(Array) && data[0] == "OK" && data[1] == event_id
          result = [ data[2] == true, data[3].to_s ]
        end
      end
      ws.on(:error) { |e| result ||= [ false, e.to_s ] }
      ws.on(:close) { result ||= [ false, "connection closed" ] }

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + RELAY_TIMEOUT
      sleep 0.05 until result || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      result || [ false, "timeout" ]
    ensure
      ws&.close
    end

    def hex?(value, length)
      value.is_a?(String) && value.match?(/\A\h{#{length}}\z/)
    end

    def placeholder_event_id(event)
      # clients sign und berechnen id; hier nur Platzhalter für UI/Flow
      SecureRandom.hex(32)
    end
  end
end

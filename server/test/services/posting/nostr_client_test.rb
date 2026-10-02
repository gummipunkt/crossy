require "test_helper"

class Posting::NostrClientTest < ActiveSupport::TestCase
  setup do
    @event = signed_nostr_event
    user = create_user
    @account = user.provider_accounts.create!(provider: "nostr", handle: "me", public_key: @event["pubkey"])
    @post = user.posts.create!(content_text: @event["content"])
    @client = Posting::NostrClient.new(@account)
  end

  test "event_id follows the NIP-01 serialization" do
    assert_equal @event["id"], Posting::NostrClient.event_id(@event)
  end

  test "verify_signed_event! accepts a valid event for the post" do
    assert @client.verify_signed_event!(@event, @post)
  end

  test "verify_signed_event! rejects content that differs from the post" do
    @post.update!(content_text: "something else")
    error = assert_raises(RuntimeError) { @client.verify_signed_event!(@event, @post) }
    assert_match "content does not match", error.message
  end

  test "verify_signed_event! rejects an event signed by another key" do
    @account.update!(public_key: "f" * 64)
    error = assert_raises(RuntimeError) { @client.verify_signed_event!(@event, @post) }
    assert_match "different key", error.message
  end

  test "verify_signed_event! rejects an id that does not match the content" do
    event = @event.merge("tags" => [ [ "t", "changed" ] ])
    error = assert_raises(RuntimeError) { @client.verify_signed_event!(event, @post) }
    assert_match "id does not match", error.message
  end

  test "verify_signed_event! rejects a forged signature" do
    event = @event.merge("sig" => "0" * 128)
    error = assert_raises(RuntimeError) { @client.verify_signed_event!(event, @post) }
    assert_match "Invalid Nostr signature", error.message
  end

  test "publish_signed_event! returns the relays that accepted the event" do
    replies = { "wss://a" => [ false, "blocked: spam" ], "wss://b" => [ true, "" ] }
    with_stubbed_method(Posting::NostrClient, :send_to_relay, ->(url, _payload, _id) { replies.fetch(url) }) do
      assert_equal [ "wss://b" ], @client.publish_signed_event!(@event, relays: replies.keys)
    end
  end

  test "publish_signed_event! raises when no relay accepts the event" do
    stub = lambda do |url, _payload, _id|
      raise "connection refused" if url == "wss://a"
      [ false, "invalid: bad signature" ]
    end
    with_stubbed_method(Posting::NostrClient, :send_to_relay, stub) do
      error = assert_raises(RuntimeError) { @client.publish_signed_event!(@event, relays: [ "wss://a", "wss://b" ]) }
      assert_match "No Nostr relay accepted", error.message
      assert_match "connection refused", error.message
      assert_match "bad signature", error.message
    end
  end
end

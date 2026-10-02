require "test_helper"

class Api::V1::NostrControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = signed_nostr_event
    @user = create_user
    @account = @user.provider_accounts.create!(provider: "nostr", handle: "n", public_key: @event["pubkey"])
    @post = @user.posts.create!(content_text: @event["content"])
    @delivery = Delivery.create!(post: @post, provider_account: @account, status: "awaiting_signature", dedup_key: "k")
    @token = ApiToken.issue!(user: @user).raw_token
  end

  test "marks the delivery succeeded only when a relay accepts the event" do
    with_stubbed_method(Posting::NostrClient, :send_to_relay, ->(_url, _payload, _id) { [ true, "" ] }) do
      publish(@event)
    end

    assert_response :success
    @delivery.reload
    assert @delivery.succeeded?
    assert_equal @event["id"], @delivery.provider_post_id
  end

  test "marks the delivery failed when every relay rejects the event" do
    with_stubbed_method(Posting::NostrClient, :send_to_relay, ->(_url, _payload, _id) { [ false, "blocked" ] }) do
      publish(@event)
    end

    assert_response :unprocessable_entity
    assert @delivery.reload.failed?
  end

  test "rejects an event with a forged signature without contacting relays" do
    relay_called = false
    with_stubbed_method(Posting::NostrClient, :send_to_relay, ->(*) { relay_called = true; [ true, "" ] }) do
      publish(@event.merge("sig" => "0" * 128))
    end

    assert_response :unprocessable_entity
    assert_not relay_called
    assert @delivery.reload.failed?
  end

  private

  def publish(event)
    post "/api/v1/nostr/publish",
         params: { post_id: @post.id, provider_account_id: @account.id, event: event }.to_json,
         headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
  end
end

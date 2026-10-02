require "test_helper"

class PostDeliveryJobTest < ActiveJob::TestCase
  class FakeClient
    attr_reader :calls

    def initialize(result: "remote-1", error: nil)
      @result = result
      @error = error
      @calls = []
    end

    def post!(post, idempotency_key: nil)
      @calls << [ post.id, idempotency_key ]
      raise @error if @error
      @result
    end
  end

  setup do
    user = create_user
    @account = user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "tok")
    @post = user.posts.create!(content_text: "hello")
    @delivery = Delivery.create!(post: @post, provider_account: @account, status: "queued", dedup_key: "key-1")
  end

  test "posts once and stores the remote id" do
    client = FakeClient.new
    perform_with(client)

    assert_equal [ [ @post.id, "key-1" ] ], client.calls
    @delivery.reload
    assert @delivery.succeeded?
    assert_equal "remote-1", @delivery.provider_post_id
  end

  test "does not post again when the delivery is no longer queued" do
    %w[in_progress succeeded failed].each do |status|
      @delivery.update!(status: status)
      client = FakeClient.new
      perform_with(client)
      assert_empty client.calls, "posted although delivery was #{status}"
    end
  end

  test "marks the delivery failed and re-raises on errors" do
    client = FakeClient.new(error: RuntimeError.new("boom"))
    assert_raises(RuntimeError) { perform_with(client) }

    @delivery.reload
    assert @delivery.failed?
    assert_equal "boom", @delivery.error_message
  end

  test "leaves Nostr deliveries to the browser signing flow" do
    nostr = @account.user.provider_accounts.create!(provider: "nostr", handle: "n", public_key: "a" * 64)
    delivery = Delivery.create!(post: @post, provider_account: nostr, status: "awaiting_signature", dedup_key: "key-2")

    PostDeliveryJob.perform_now(delivery.id)
    assert delivery.reload.awaiting_signature?
  end

  private

  def perform_with(client)
    job = PostDeliveryJob.new(@delivery.id)
    job.define_singleton_method(:client_for) { |_account| client }
    job.perform_now
  end
end

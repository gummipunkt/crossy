require "test_helper"

class Posting::MastodonClientTest < ActiveSupport::TestCase
  test "sends the delivery's dedup key as Idempotency-Key" do
    user = create_user
    account = user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "tok")
    post = user.posts.create!(content_text: "hello fediverse")

    received_key = nil
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/api/v1/statuses") do |env|
      received_key = env.request_headers["Idempotency-Key"]
      [ 200, {}, { id: "111" }.to_json ]
    end

    client = Posting::MastodonClient.new(account)
    client.define_singleton_method(:connection) do |_base_url|
      Faraday.new { |f| f.request :url_encoded; f.adapter :test, stubs }
    end

    assert_equal "111", client.post!(post, idempotency_key: "dedup-123")
    assert_equal "dedup-123", received_key
  end
end

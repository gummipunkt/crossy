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

  test "waits until asynchronously processed media is ready before posting" do
    user = create_user
    account = user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "tok")
    post = user.posts.create!(content_text: "with video")
    ma = post.media_attachments.create!(filename: "clip.mp4", content_type: "video/mp4", byte_size: 3, metadata: { alt: "a clip" })
    ma.file.attach(io: StringIO.new("abc"), filename: "clip.mp4", content_type: "video/mp4")

    media_states = [ 206, 206, 200 ]
    status_body = nil
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/api/v2/media") { [ 202, {}, { id: "m1", url: nil }.to_json ] }
    stubs.get("/api/v1/media/m1") { [ media_states.shift, {}, { id: "m1" }.to_json ] }
    stubs.post("/api/v1/statuses") do |env|
      status_body = env.body
      [ 200, {}, { id: "222" }.to_json ]
    end

    client = Posting::MastodonClient.new(account)
    fake = Faraday.new { |f| f.request :url_encoded; f.adapter :test, stubs }
    client.define_singleton_method(:connection) { |_base_url| fake }
    client.define_singleton_method(:upload_connection) { |_base_url| fake }
    client.define_singleton_method(:pause) { |_seconds| }

    assert_equal "222", client.post!(post.reload)
    assert_empty media_states
    assert_includes status_body, "media_ids"
  end
end

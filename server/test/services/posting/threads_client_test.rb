require "test_helper"

class Posting::ThreadsClientTest < ActiveSupport::TestCase
  setup do
    user = create_user
    @account = user.provider_accounts.create!(provider: "threads", handle: "42", access_token: "tok")
    @post = user.posts.create!(content_text: "hello threads")
    @stubs = Faraday::Adapter::Test::Stubs.new
    @stubs.post("/v1.0/42/threads") { [ 200, {}, { id: "container-1" }.to_json ] }
  end

  test "waits for the container and returns the published media id" do
    statuses = %w[IN_PROGRESS FINISHED]
    @stubs.get("/v1.0/container-1") { [ 200, {}, { status: statuses.shift }.to_json ] }
    @stubs.post("/v1.0/42/threads_publish") { [ 200, {}, { id: "media-9" }.to_json ] }

    assert_equal "media-9", post!
    assert_empty statuses
    @stubs.verify_stubbed_calls
  end

  test "raises when publishing fails instead of reporting the container id" do
    @stubs.get("/v1.0/container-1") { [ 200, {}, { status: "FINISHED" }.to_json ] }
    @stubs.post("/v1.0/42/threads_publish") { [ 400, {}, { error: { message: "Media not ready" } }.to_json ] }

    error = assert_raises(RuntimeError) { post! }
    assert_match "Threads publish failed: 400", error.message
  end

  test "raises when the container failed to process" do
    @stubs.get("/v1.0/container-1") { [ 200, {}, { status: "ERROR", error_message: "bad image" }.to_json ] }

    error = assert_raises(RuntimeError) { post! }
    assert_match "ERROR: bad image", error.message
  end

  private

  def post!
    stubs = @stubs
    client = Posting::ThreadsClient.new(@account)
    client.define_singleton_method(:connection) do
      Faraday.new { |f| f.request :url_encoded; f.adapter :test, stubs }
    end
    client.define_singleton_method(:pause) { |_seconds| }
    with_env("THREADS_APP_ID" => "app") { client.post!(@post) }
  end
end

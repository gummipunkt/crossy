require "test_helper"

class Posting::BlueskyClientTest < ActiveSupport::TestCase
  setup do
    user = create_user
    @account = user.provider_accounts.create!(provider: "bluesky", handle: "me.bsky.social", refresh_token: "jwt")
    @post = user.posts.create!(content_text: "hi")
    @client = Posting::BlueskyClient.new(@account)
    # Validation must fail before any network call.
    @client.define_singleton_method(:session!) { raise "network must not be used" }
  end

  test "rejects posts longer than 300 graphemes" do
    @post.update!(content_text: "🙂" * 301)
    error = assert_raises(RuntimeError) { @client.post!(@post) }
    assert_match "limited to 300 characters (this one has 301)", error.message
  end

  test "counts graphemes, not bytes" do
    @post.update!(content_text: "🙂" * 300)
    error = assert_raises(RuntimeError) { @client.post!(@post) }
    assert_equal "network must not be used", error.message
  end

  test "rejects images over the size limit" do
    attach(@post, "big.jpg", "image/jpeg", "x" * 1_000_001)
    error = assert_raises(RuntimeError) { @client.post!(@post.reload) }
    assert_match "big.jpg is 1000 KB", error.message
  end

  test "rejects non-image attachments" do
    attach(@post, "clip.mp4", "video/mp4", "x")
    error = assert_raises(RuntimeError) { @client.post!(@post.reload) }
    assert_match "clip.mp4 (video/mp4) is not supported", error.message
  end

  private

  def attach(post, filename, content_type, bytes)
    ma = post.media_attachments.create!(filename: filename, content_type: content_type, byte_size: bytes.bytesize, metadata: {})
    ma.file.attach(io: StringIO.new(bytes), filename: filename, content_type: content_type)
  end
end

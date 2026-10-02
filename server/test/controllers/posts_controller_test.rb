require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    sign_in @user
    @mastodon = @user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "tok")
    @nostr = @user.provider_accounts.create!(provider: "nostr", handle: "n", public_key: "a" * 64)
  end

  test "Nostr deliveries wait for a signature and get no delivery job" do
    assert_enqueued_jobs 1, only: PostDeliveryJob do
      post posts_path, params: { post: { content_text: "hello" }, provider_account_ids: [ @mastodon.id, @nostr.id ] }
    end

    post = @user.posts.last
    assert post.deliveries.find_by(provider_account: @mastodon).queued?
    assert post.deliveries.find_by(provider_account: @nostr).awaiting_signature?
  end
end

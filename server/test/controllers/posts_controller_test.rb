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

  test "a scheduled post enqueues nothing until it is due" do
    assert_no_enqueued_jobs only: PostDeliveryJob do
      post posts_path, params: { post: { content_text: "later", scheduled_at: 2.hours.from_now.iso8601 }, provider_account_ids: [ @mastodon.id ] }
    end

    post = @user.posts.last
    assert post.scheduled_for_later?
    assert post.deliveries.first.scheduled?
    assert_match "Post scheduled for", flash[:notice]
  end

  test "publish_now sends a scheduled post right away" do
    scheduled = @user.posts.create!(content_text: "later", scheduled_at: 2.hours.from_now)
    delivery = Delivery.create!(post: scheduled, provider_account: @mastodon, status: "scheduled", dedup_key: "k1")

    assert_enqueued_with(job: PostDeliveryJob, args: [ delivery.id ]) do
      post publish_now_post_path(scheduled)
    end
    assert delivery.reload.queued?
  end

  test "cancel_schedule stops scheduled deliveries" do
    scheduled = @user.posts.create!(content_text: "later", scheduled_at: 2.hours.from_now)
    delivery = Delivery.create!(post: scheduled, provider_account: @mastodon, status: "scheduled", dedup_key: "k2")

    post cancel_schedule_post_path(scheduled)
    assert delivery.reload.failed?
    assert_nil scheduled.reload.scheduled_at
  end

  test "retry button re-queues a failed delivery" do
    failed = @user.posts.create!(content_text: "oops")
    delivery = Delivery.create!(post: failed, provider_account: @mastodon, status: "failed", error_message: "x", dedup_key: "k3")

    assert_enqueued_with(job: PostDeliveryJob, args: [ delivery.id ]) do
      post retry_post_delivery_path(failed, delivery)
    end
    assert_redirected_to failed
    assert delivery.reload.queued?
  end

  test "cannot retry another user's delivery" do
    other = create_user
    other_account = other.provider_accounts.create!(provider: "mastodon", handle: "o", instance: "https://o.example", access_token: "t")
    other_post = other.posts.create!(content_text: "theirs")
    delivery = Delivery.create!(post: other_post, provider_account: other_account, status: "failed", dedup_key: "k4")

    post retry_post_delivery_path(other_post, delivery)
    assert_response :not_found
    assert delivery.reload.failed?
  end

  test "composer and post page render the schedule and retry controls" do
    get new_post_path
    assert_response :success
    assert_select "input[type=datetime-local][data-schedule-input]"

    scheduled = @user.posts.create!(content_text: "later", scheduled_at: 2.hours.from_now)
    Delivery.create!(post: scheduled, provider_account: @mastodon, status: "scheduled", dedup_key: "k5")
    get post_path(scheduled)
    assert_response :success
    assert_select "time[data-local-time]"
    assert_select "form[action=?]", publish_now_post_path(scheduled)

    failed = @user.posts.create!(content_text: "oops")
    delivery = Delivery.create!(post: failed, provider_account: @mastodon, status: "failed", error_message: "x", dedup_key: "k6")
    get post_path(failed)
    assert_select "form[action=?][data-turbo-frame=_top]", retry_post_delivery_path(failed, delivery)

    get my_path
    assert_response :success
  end
end

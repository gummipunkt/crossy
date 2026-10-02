require "test_helper"

class SchedulingAndRetryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = create_user
    @mastodon = @user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "t")
    @nostr = @user.provider_accounts.create!(provider: "nostr", handle: "n", public_key: "a" * 64)
  end

  test "a schedule in the past is rejected" do
    post = @user.posts.build(content_text: "hi", scheduled_at: 10.minutes.ago)
    assert_not post.valid?
    assert_includes post.errors[:scheduled_at], "must be in the future"
  end

  test "a schedule within the grace period means post now" do
    post = @user.posts.create!(content_text: "hi", scheduled_at: 30.seconds.from_now)
    assert_nil post.scheduled_at
    assert_equal "queued", Delivery.initial_status_for(@mastodon, post)
  end

  test "deliveries of a later post start scheduled, Nostr still waits for a signature" do
    post = @user.posts.create!(content_text: "hi", scheduled_at: 1.hour.from_now)
    assert_equal "scheduled", Delivery.initial_status_for(@mastodon, post)
    assert_equal "awaiting_signature", Delivery.initial_status_for(@nostr, post)
  end

  test "dispatch_due! queues due deliveries exactly once" do
    due = scheduled_delivery(scheduled_at: 1.hour.from_now)
    later = scheduled_delivery(scheduled_at: 2.hours.from_now)
    due.post.update_columns(scheduled_at: 1.minute.ago)

    assert_enqueued_with(job: PostDeliveryJob, args: [ due.id ]) do
      assert_equal 1, DispatchScheduledPostsJob.new.perform
    end
    assert due.reload.queued?
    assert later.reload.scheduled?

    assert_no_enqueued_jobs { Delivery.dispatch_due! }
  end

  test "retry! re-queues a failed delivery with its original dedup key" do
    delivery = make_delivery(@mastodon, status: "failed", error_message: "boom")

    assert_enqueued_with(job: PostDeliveryJob, args: [ delivery.id ]) do
      assert delivery.retry!
    end
    assert delivery.queued?
    assert_nil delivery.error_message
    assert_equal "key-#{@mastodon.id}", delivery.dedup_key
  end

  test "retry! hands a failed Nostr delivery back to the signing flow" do
    delivery = make_delivery(@nostr, status: "failed")
    assert_no_enqueued_jobs { assert delivery.retry! }
    assert delivery.awaiting_signature?
  end

  test "only failed deliveries can be retried" do
    delivery = make_delivery(@mastodon, status: "succeeded")
    assert_no_enqueued_jobs { assert_not delivery.retry! }
  end

  private

  def scheduled_delivery(scheduled_at:)
    post = @user.posts.create!(content_text: "later", scheduled_at: scheduled_at)
    Delivery.create!(post: post, provider_account: @mastodon, status: "scheduled", dedup_key: SecureRandom.uuid)
  end

  def make_delivery(account, status:, error_message: nil)
    post = @user.posts.create!(content_text: "hi")
    Delivery.create!(post: post, provider_account: account, status: status, error_message: error_message, dedup_key: "key-#{account.id}")
  end
end

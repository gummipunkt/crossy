require "test_helper"

class DeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    user = create_user
    account = user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "t")
    post = user.posts.create!(content_text: "hi")
    @delivery = Delivery.create!(post: post, provider_account: account, status: "succeeded", provider_post_id: "1", dedup_key: "k")
  end

  test "enqueues one engagement sync per interval, however often the page is viewed" do
    assert_enqueued_jobs 1, only: SyncDeliveryEngagementJob do
      3.times { Delivery.enqueue_stale_engagement_syncs([ @delivery.reload ]) }
    end
  end

  test "enqueues again once the interval has passed" do
    @delivery.update!(metrics_sync_enqueued_at: (Delivery::METRICS_STALE_AFTER + 1.minute).ago)
    assert_enqueued_jobs 1, only: SyncDeliveryEngagementJob do
      Delivery.enqueue_stale_engagement_syncs([ @delivery ])
    end
  end

  test "skips deliveries with fresh metrics" do
    @delivery.update!(metrics_fetched_at: Time.current)
    assert_no_enqueued_jobs { Delivery.enqueue_stale_engagement_syncs([ @delivery ]) }
  end
end

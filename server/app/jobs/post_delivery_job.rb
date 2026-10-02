class PostDeliveryJob < ApplicationJob
  queue_as :default

  def perform(delivery_id)
    delivery = Delivery.find(delivery_id)
    # Nostr events are signed in the browser and published via Api::V1::NostrController.
    return if delivery.provider_account.provider == "nostr"

    # Claim the delivery atomically: a duplicate or re-run job finds it no
    # longer queued and stops, so the post is never sent twice.
    claimed = Delivery.where(id: delivery.id, status: "queued")
                      .update_all(status: "in_progress", started_at: Time.current, updated_at: Time.current)
    return if claimed.zero?

    delivery.reload
    client = client_for(delivery.provider_account)
    provider_post_id = client.post!(delivery.post, idempotency_key: delivery.dedup_key)

    delivery.update!(status: "succeeded", provider_post_id: provider_post_id, finished_at: Time.current)
  rescue => e
    if delivery
      Delivery.where(id: delivery.id, status: "in_progress")
              .update_all(status: "failed", error_message: e.message, finished_at: Time.current, updated_at: Time.current)
    end
    raise e
  end

  private

  def client_for(provider_account)
    case provider_account.provider
    when "mastodon" then Posting::MastodonClient.new(provider_account)
    when "bluesky" then Posting::BlueskyClient.new(provider_account)
    when "threads" then Posting::ThreadsClient.new(provider_account)
    else
      raise "Unknown provider: #{provider_account.provider}"
    end
  end
end

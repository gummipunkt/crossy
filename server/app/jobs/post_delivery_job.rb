class PostDeliveryJob < ApplicationJob
  queue_as :default

  def perform(delivery_id)
    delivery = Delivery.find(delivery_id)
    return if delivery.succeeded?

    delivery.update!(status: "in_progress", started_at: Time.current)

    client = client_for(delivery.provider_account)
    provider_post_id = client.post!(delivery.post)

    delivery.update!(status: "succeeded", provider_post_id: provider_post_id, finished_at: Time.current)
  rescue => e
    delivery.update!(status: "failed", error_message: e.message, finished_at: Time.current) if delivery
    raise e
  end

  private

  def client_for(provider_account)
    case provider_account.provider
    when "mastodon" then Posting::MastodonClient.new(provider_account)
    when "bluesky" then Posting::BlueskyClient.new(provider_account)
    when "threads" then Posting::ThreadsClient.new(provider_account)
    when "nostr" then Posting::NostrClient.new(provider_account)
    else
      raise "Unknown provider: #{provider_account.provider}"
    end
  end
end

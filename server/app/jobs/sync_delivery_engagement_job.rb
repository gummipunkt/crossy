class SyncDeliveryEngagementJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(delivery_id)
    delivery = Delivery.find_by(id: delivery_id)
    return unless delivery

    Engagement::Syncer.new(delivery).call
  end
end

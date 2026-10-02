class DispatchScheduledPostsJob < ApplicationJob
  queue_as :default

  # Runs every minute (config/recurring.yml) and queues deliveries of posts
  # whose scheduled time has come.
  def perform
    Delivery.dispatch_due!
  end
end

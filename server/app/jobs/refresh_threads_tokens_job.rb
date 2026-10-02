class RefreshThreadsTokensJob < ApplicationJob
  queue_as :default

  # Threads long-lived tokens expire after ~60 days and can only be refreshed
  # while still valid, so idle accounts need this even when nobody posts.
  def perform
    Threads::TokenRefresher.refresh_expiring!
  end
end

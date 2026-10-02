require "faraday"
require "json"

module Threads
  # Exchanges a long-lived Threads token for a fresh one (valid ~60 days).
  # Only a still-valid token can be refreshed, so this must run before expiry.
  class TokenRefresher
    REFRESH_BEFORE = 7.days

    def self.refresh_expiring!
      ProviderAccount.where(provider: "threads")
                     .where(threads_token_expires_at: [ nil, ..REFRESH_BEFORE.from_now ])
                     .find_each do |account|
        new(account).refresh!
      rescue => e
        Rails.logger.warn("Threads token refresh failed for account #{account.id}: #{e.message}")
      end
    end

    def initialize(account)
      @account = account
    end

    # Returns the new token, or nil when Threads rejected the token (the
    # account is then marked so the user knows to reconnect). Server errors
    # raise, so a temporary outage does not flag the account.
    def refresh!
      resp = connection.get("/refresh_access_token", grant_type: "th_refresh_token", access_token: @account.access_token)
      raise "Threads token refresh failed: HTTP #{resp.status}" if resp.status >= 500

      body = (JSON.parse(resp.body) rescue {})
      token = body["access_token"]

      unless resp.success? && token.present?
        @account.update!(status: "reauth_required")
        return nil
      end

      expires_at = body["expires_in"].present? ? body["expires_in"].to_i.seconds.from_now.utc : nil
      @account.update!(access_token: token, threads_token_expires_at: expires_at, status: "active")
      token
    end

    private

    def connection
      Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE, request: { timeout: 10, open_timeout: 5 }) do |f|
        f.adapter Faraday.default_adapter
      end
    end
  end
end

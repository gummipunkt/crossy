require "faraday"
require "json"

# Connects Mastodon, Bluesky and Nostr accounts for a user. Shared by the web
# and API controllers so both apply the same checks. Accounts are only saved
# once the credentials have been verified, and connecting the same account
# again updates its credentials instead of failing.
class ProviderConnector
  class Error < StandardError; end

  # "write" is Mastodon's umbrella scope and includes write:statuses.
  MASTODON_POST_SCOPES = %w[write write:statuses].freeze

  def initialize(user)
    @user = user
  end

  def mastodon!(handle:, instance:, access_token:)
    instance = normalize_instance!(instance)
    token = access_token.to_s.strip
    raise Error, "Mastodon access token missing" if token.blank?

    conn = connection(instance)
    verify = conn.get("/api/v1/accounts/verify_credentials") { |req| authorize(req, token) }
    raise Error, "Mastodon token invalid (HTTP #{verify.status})" unless verify.success?

    scopes = mastodon_scopes(conn, token)
    if scopes && (scopes & MASTODON_POST_SCOPES).empty?
      raise Error, "Mastodon token is missing the write:statuses scope"
    end

    account = find_or_initialize("mastodon", handle, instance)
    account.update!(access_token: token, scopes: scopes&.join(" "), status: "active")
    account
  rescue ActiveRecord::RecordNotUnique
    raise Error, "This Mastodon account is already connected by another user"
  end

  def bluesky!(handle:, app_password:, instance: nil)
    instance = instance.present? ? normalize_instance!(instance) : nil
    account = find_or_initialize("bluesky", handle, instance)
    # login! saves the account only after Bluesky accepted the app password.
    Posting::BlueskyClient.new(account).login!(app_password)
    account.update!(status: "active") unless account.status == "active"
    account
  rescue ActiveRecord::RecordNotUnique
    raise Error, "This Bluesky account is already connected by another user"
  end

  def nostr!(handle:, public_key:)
    key = public_key.to_s.strip.downcase
    unless key.match?(/\A\h{64}\z/)
      raise Error, "Nostr public key must be 64 hex characters (not an npub)"
    end

    account = find_or_initialize("nostr", handle, nil)
    account.update!(public_key: key, status: "active")
    account
  rescue ActiveRecord::RecordNotUnique
    raise Error, "This Nostr account is already connected by another user"
  end

  private

  def find_or_initialize(provider, handle, instance)
    handle = handle.to_s.strip
    raise Error, "Handle missing" if handle.blank?

    @user.provider_accounts.find_or_initialize_by(provider: provider, handle: handle, instance: instance)
  end

  def normalize_instance!(instance)
    url = instance.to_s.strip
    url = "https://#{url}" unless url.start_with?("http://", "https://")
    url = url.sub(%r{/+\z}, "")
    SsrfSafeUrlValidator.validate!(url)
    url
  rescue SsrfSafeUrlValidator::Error => e
    raise Error, "Instance URL not allowed: #{e.message}"
  end

  # Returns the token's scopes, or nil when the server does not expose them.
  def mastodon_scopes(conn, token)
    info = conn.get("/oauth/token/info") { |req| authorize(req, token) }
    return nil unless info.success?

    raw = (JSON.parse(info.body) rescue {})["scopes"]
    return nil if raw.blank?

    raw.is_a?(Array) ? raw : raw.to_s.split(/\s+/)
  rescue Faraday::Error
    nil
  end

  def authorize(req, token)
    req.headers["Authorization"] = "Bearer #{token}"
    req.headers["Accept"] = "application/json"
    req.options.timeout = 10
    req.options.open_timeout = 5
  end

  def connection(instance)
    SafeHttp.connection(instance)
  end
end

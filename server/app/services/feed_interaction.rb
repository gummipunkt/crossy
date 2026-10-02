require "erb"
require "faraday"
require "json"

# Like / repost / bookmark a timeline item through the account whose feed it
# came from. Shared by the web timeline and the JSON API.
class FeedInteraction
  class UnsupportedAction < ArgumentError; end

  def initialize(user)
    @user = user
  end

  # Returns true when the provider accepted the action.
  def perform!(provider:, item_id:, action:, cid: nil, provider_account_id: nil)
    account = account_for(provider, provider_account_id)

    case provider
    when "mastodon" then mastodon(account, item_id, action)
    when "bluesky"  then bluesky(account, item_id, action, cid)
    when "threads"  then threads(account, item_id, action)
    else raise UnsupportedAction, "unsupported provider"
    end
  end

  private

  # Items carry their provider_account_id; older clients that do not send it
  # fall back to the user's first account of that provider.
  def account_for(provider, provider_account_id)
    scope = @user.provider_accounts.where(provider: provider)
    provider_account_id.present? ? scope.find(provider_account_id) : scope.order(:id).first!
  end

  def mastodon(account, item_id, action)
    path =
      case action
      when "like"     then "favourite"
      when "bookmark" then "bookmark"
      when "repost"   then "reblog"
      else raise UnsupportedAction, "unsupported action"
      end
    resp = connection(account.instance).post("/api/v1/statuses/#{escape(item_id)}/#{path}") do |req|
      req.headers["Authorization"] = "Bearer #{account.access_token}"
    end
    resp.success?
  end

  def bluesky(account, item_id, action, cid)
    collection =
      case action
      when "like"   then "app.bsky.feed.like"
      when "repost" then "app.bsky.feed.repost"
      else raise UnsupportedAction, "unsupported action"
      end

    did, access = Posting::BlueskyClient.new(account).session!
    subject = { "uri" => item_id }
    subject["cid"] = cid if cid.present?
    body = {
      repo: did,
      collection: collection,
      record: { "$type" => collection, "subject" => subject, "createdAt" => Time.now.utc.iso8601 }
    }
    base = account.instance.presence || Posting::BlueskyClient::DEFAULT_BASE
    resp = connection(base).post("/xrpc/com.atproto.repo.createRecord") do |req|
      req.headers["Authorization"] = "Bearer #{access}"
      req.headers["Content-Type"] = "application/json"
      req.body = JSON.dump(body)
    end
    resp.success?
  end

  def threads(account, item_id, action)
    path =
      case action
      when "like"   then "likes"
      when "repost" then "reposts"
      else raise UnsupportedAction, "unsupported action"
      end
    resp = connection(Posting::ThreadsClient::GRAPH_BASE).post("/v1.0/#{escape(item_id)}/#{path}") do |req|
      req.body = { access_token: account.access_token }
    end
    resp.success?
  end

  def escape(segment)
    ERB::Util.url_encode(segment.to_s)
  end

  def connection(base_url)
    Faraday.new(url: base_url, request: { timeout: 10, open_timeout: 5 }) do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end
  end
end

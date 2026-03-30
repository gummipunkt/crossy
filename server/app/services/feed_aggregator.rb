require "faraday"
require "json"
require "time"

class FeedAggregator
  Item = Struct.new(
    :provider, :id, :author, :content, :created_at, :url, :images,
    :avatar_url,
    :likes_count, :reposts_count, :replies_count,
    :liked_by_me, :reposted_by_me, :bookmarked_by_me,
    :cid,
    :reblogged_by,
    keyword_init: true
  )

  def aggregate(limit: 50, user: nil)
    buckets = {
      mastodon: fetch_mastodon(user),
      bluesky: fetch_bluesky(user),
      threads: fetch_threads(user)
    }

    # Guarantee each provider gets at least `min_per_provider` slots so
    # a very active provider cannot push others out of the feed entirely.
    min_per_provider = [ limit / [ buckets.count { |_, v| v.any? }, 1 ].max, 5 ].min
    reserved = []
    remainder = []

    buckets.each_value do |list|
      sorted = list.sort_by { |i| -(i.created_at&.to_f || 0) }
      reserved.concat(sorted.first(min_per_provider))
      remainder.concat(sorted.drop(min_per_provider))
    end

    remainder.sort_by! { |i| -(i.created_at&.to_f || 0) }
    result = reserved + remainder.first(limit - reserved.size)
    result.sort_by { |i| -(i.created_at&.to_f || 0) }.first(limit)
  rescue => e
    Rails.logger.error("Feed aggregate error: #{e.message}")
    []
  end

  private

  def fetch_mastodon(user)
    list = []
    rel = ProviderAccount.where(provider: "mastodon")
    rel = rel.where(user_id: user.id) if user
    rel.find_each do |pa|
      next if pa.access_token.blank? || pa.instance.blank?
      conn = Faraday.new(url: pa.instance) { |f| f.adapter Faraday.default_adapter }
      resp = conn.get("/api/v1/timelines/home") do |req|
        req.headers["Authorization"] = "Bearer #{pa.access_token}"
        req.headers["Accept"] = "application/json"
      end
      next unless resp.success?
      (JSON.parse(resp.body) rescue []).each do |st|
        # For reblogs the actual content lives in the nested "reblog" object;
        # the outer status has empty content and url=nil.
        display = st["reblog"].presence || st
        reblogger = st["reblog"].present? ? st.dig("account", "acct") : nil

        images = Array(display["media_attachments"]).map { |m| { "url" => (m["preview_url"] || m["url"]), "alt" => m["description"].to_s } }
        list << Item.new(
          provider: "mastodon",
          id: st["id"],
          author: display.dig("account", "acct"),
          content: ActionView::Base.full_sanitizer.sanitize(display["content"].to_s),
          created_at: (Time.parse(st["created_at"]) rescue nil),
          url: display["url"],
          images: (images.presence),
          avatar_url: display.dig("account", "avatar_static") || display.dig("account", "avatar"),
          likes_count: display["favourites_count"].to_i,
          reposts_count: display["reblogs_count"].to_i,
          replies_count: display["replies_count"].to_i,
          liked_by_me: !!display["favourited"],
          reposted_by_me: !!display["reblogged"],
          bookmarked_by_me: !!display["bookmarked"],
          reblogged_by: reblogger
        )
      end
    end
    list
  end

  def fetch_bluesky(user)
    list = []
    rel = ProviderAccount.where(provider: "bluesky")
    rel = rel.where(user_id: user.id) if user
    rel.find_each do |pa|
      begin
        did, access = ensure_bluesky_session(pa)
        conn = Faraday.new(url: (pa.instance.presence || Posting::BlueskyClient::DEFAULT_BASE)) { |f| f.adapter Faraday.default_adapter }
        resp = conn.get("/xrpc/app.bsky.feed.getTimeline") do |req|
          req.headers["Authorization"] = "Bearer #{access}"
          req.headers["Accept"] = "application/json"
        end
        next unless resp.success?
        (JSON.parse(resp.body)["feed"] rescue []).each do |it|
          post = it["post"] || {}
          images = nil
          emb = post["embed"]
          if emb && (emb["$type"]&.include?("images#view") || emb.dig("media", "$type")&.include?("images#view"))
            imgs = emb["images"] || emb.dig("media", "images")
            images = Array(imgs).map { |im| { "url" => (im["fullsize"] || im["thumb"]), "alt" => im["alt"].to_s } }
          end
          uri = post["uri"].to_s
          rkey = uri.split("/")[-1]
          handle_or_did = post.dig("author", "handle") || post.dig("author", "did")
          bsky_url = (handle_or_did && rkey) ? "https://bsky.app/profile/#{handle_or_did}/post/#{rkey}" : nil

          viewer = post["viewer"] || {}
          list << Item.new(
            provider: "bluesky",
            id: post["uri"],
            author: post.dig("author", "handle"),
            content: post.dig("record", "text").to_s,
            created_at: (Time.parse(post.dig("record", "createdAt").to_s) rescue nil),
            url: bsky_url,
            images: images,
            avatar_url: post.dig("author", "avatar"),
            likes_count: post["likeCount"].to_i,
            reposts_count: post["repostCount"].to_i,
            replies_count: post["replyCount"].to_i,
            liked_by_me: viewer["like"].present?,
            reposted_by_me: viewer["repost"].present?,
            cid: post["cid"]
          )
        end
      rescue => _e
        next
      end
    end
    list
  end

  def fetch_threads(user)
    list = []
    rel = ProviderAccount.where(provider: "threads")
    rel = rel.where(user_id: user.id) if user
    rel.find_each do |pa|
      next if pa.access_token.blank?
      app_id = ENV.fetch("THREADS_APP_ID")
      conn = Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE) { |f| f.request :url_encoded; f.adapter Faraday.default_adapter }

      fields = %w[
        id media_product_type media_type media_url permalink username text timestamp shortcode thumbnail_url
        children{id,media_type,media_url,thumbnail_url}
      ].join(",")
      data = nil
      resp2 = conn.get("/v1.0/me/threads", { access_token: pa.access_token, fields: fields, limit: 25 }, { "X-IG-App-ID" => app_id })
      if resp2.success?
        data = (JSON.parse(resp2.body)["data"] rescue nil)
      elsif resp2.status == 400 && (JSON.parse(resp2.body) rescue {}).dig("error", "code") == 190
        if (new_token = refresh_threads_token(pa))
          resp2 = conn.get("/v1.0/me/threads", { access_token: new_token, fields: fields, limit: 25 }, { "X-IG-App-ID" => app_id })
          data = (JSON.parse(resp2.body)["data"] rescue nil) if resp2.success?
        end
      end

      Array(data).each do |it|
        images = extract_threads_images(it)

        list << Item.new(
          provider: "threads",
          id: it["id"],
          author: it["username"],
          content: it["text"].to_s,
          created_at: (it["timestamp"] ? Time.parse(it["timestamp"]) : nil),
          url: it["permalink"],
          images: images
        )
      end
    end
    list
  end

  def ensure_bluesky_session(pa)
    did, access = nil, nil
    begin
      client = Posting::BlueskyClient.new(pa)
      did, access = client.send(:ensure_session)
    rescue => _e
    end
    [ did, access ]
  end

  def refresh_threads_token(pa)
    conn = Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE) { |f| f.request :url_encoded; f.adapter Faraday.default_adapter }
    resp = conn.get("/refresh_access_token", { grant_type: "th_refresh_token", access_token: pa.access_token })
    return nil unless resp.success?
    new_token = (JSON.parse(resp.body) rescue {})["access_token"]
    if new_token.present?
      pa.update!(access_token: new_token)
      return new_token
    end
    nil
  end

  def extract_threads_images(obj)
    if obj["media_type"].to_s == "IMAGE"
      url = obj["media_url"].presence || obj["thumbnail_url"].presence
      return [ { "url" => url, "alt" => obj["alt_text"].to_s } ] if url
    elsif obj["media_type"].to_s == "CAROUSEL_ALBUM" && obj["children"].is_a?(Hash)
      imgs = Array(obj.dig("children", "data")).first(4).filter_map do |ch|
        url = ch["media_url"] || ch["thumbnail_url"]
        { "url" => url, "alt" => "" } if url.present?
      end
      return imgs if imgs.any?
    elsif obj["media_type"].to_s == "VIDEO" && obj["thumbnail_url"].present?
      return [ { "url" => obj["thumbnail_url"], "alt" => obj["alt_text"].to_s } ]
    end
    nil
  end
end

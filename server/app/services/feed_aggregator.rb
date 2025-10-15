require "faraday"
require "json"
require "time"

class FeedAggregator
  Item = Struct.new(:provider, :id, :author, :content, :created_at, :url, :images, keyword_init: true)

  def aggregate(limit: 50, user: nil)
    items = []
    items.concat fetch_mastodon(user)
    items.concat fetch_bluesky(user)
    items.concat fetch_threads(user)
    items.sort_by! { |i| i.created_at || Time.at(0) }
    items.reverse.first(limit)
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
        images = Array(st["media_attachments"]).map { |m| { "url" => (m["preview_url"] || m["url"]), "alt" => m["description"].to_s } }
        list << Item.new(
          provider: "mastodon",
          id: st["id"],
          author: st.dig("account", "acct"),
          content: ActionView::Base.full_sanitizer.sanitize(st["content"].to_s),
          created_at: (Time.parse(st["created_at"]) rescue nil),
          url: st["url"],
          images: (images.presence)
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
          if emb && (emb["$type"]&.include?("images#view") || emb.dig("media","$type")&.include?("images#view"))
            imgs = emb["images"] || emb.dig("media","images")
            images = Array(imgs).map { |im| { "url" => (im["fullsize"] || im["thumb"]), "alt" => im["alt"].to_s } }
          end
          # Baue eine öffentliche Bluesky-Web-URL
          uri = post["uri"].to_s
          rkey = uri.split('/')[-1]
          handle_or_did = post.dig("author", "handle") || post.dig("author", "did")
          bsky_url = (handle_or_did && rkey) ? "https://bsky.app/profile/#{handle_or_did}/post/#{rkey}" : nil
          list << Item.new(
            provider: "bluesky",
            id: post["uri"],
            author: post.dig("author", "handle"),
            content: post.dig("record", "text").to_s,
            created_at: (Time.parse(post.dig("record", "createdAt").to_s) rescue nil),
            url: bsky_url,
            images: images
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
      conn = Faraday.new(url: Posting::ThreadsClient::GRAPH_BASE) { |f| f.request :url_encoded; f.adapter Faraday.default_adapter }

      # Direkter Abruf inkl. Felder laut Doku
      fields = %w[
        id media_product_type media_type media_url permalink username text timestamp shortcode thumbnail_url
        children{id,media_type,media_url,thumbnail_url}
      ].join(',')
      data = nil
      resp2 = conn.get("/v1.0/me/threads", { access_token: pa.access_token, fields: fields, limit: 25 })
      if resp2.success?
        data = (JSON.parse(resp2.body)["data"] rescue nil)
      elsif resp2.status == 400 && (JSON.parse(resp2.body) rescue {}).dig("error","code") == 190
        if (new_token = refresh_threads_token(pa))
          resp2 = conn.get("/v1.0/me/threads", { access_token: new_token, fields: fields, limit: 25 })
          data = (JSON.parse(resp2.body)["data"] rescue nil) if resp2.success?
        end
      end

      Array(data).each do |it|
        tid = it["id"]
        author = it["username"]
        text = it["text"].to_s
        created = it["timestamp"]
        permalink = it["permalink"]

        images = []
        if it["media_type"].to_s == "IMAGE"
          if it["media_url"].present?
            images << { "url" => it["media_url"], "alt" => it["alt_text"].to_s }
          elsif it["thumbnail_url"].present?
            images << { "url" => it["thumbnail_url"], "alt" => it["alt_text"].to_s }
          end
        elsif it["media_type"].to_s == "CAROUSEL_ALBUM" && it["children"].is_a?(Hash)
          Array(it.dig("children","data")).first(4).each do |ch|
            url = ch["media_url"] || ch["thumbnail_url"]
            images << { "url" => url, "alt" => "" } if url.present?
          end
        elsif it["media_type"].to_s == "VIDEO" && it["thumbnail_url"].present?
          images << { "url" => it["thumbnail_url"], "alt" => it["alt_text"].to_s }
        end
        images = nil if images.empty?

        list << Item.new(
          provider: "threads",
          id: tid,
          author: author,
          content: text,
          created_at: (created ? Time.parse(created) : nil),
          url: permalink,
          images: images
        )
      end
    end
    list
  end

  def ensure_bluesky_session(pa)
    did, access = nil, nil
    begin
      # Reuse BlueskyClient logic
      client = Posting::BlueskyClient.new(pa)
      did, access = client.send(:ensure_session)
    rescue => _e
    end
    [did, access]
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

  # Ruft Details zu einem Threads-Post ab und mappt auf Item
  def fetch_threads_detail(conn, token, tid)
    resp = conn.get("/v1.0/#{tid}", {
      access_token: token,
      # Threads/Media-ähnliche Felder (analog IG Graph):
      # Vermeide feldspezifische Fehler wie "content" auf Media
      fields: [
        'id',
        'permalink', 'permalink_url',
        'timestamp',
        'caption', 'username',
        'media_type', 'media_url', 'thumbnail_url',
        'children{media_type,media_url,thumbnail_url}'
      ].join(',')
    })
    return nil unless resp.success?
    obj = JSON.parse(resp.body) rescue nil
    return nil unless obj

    images = extract_threads_images(obj)

    Item.new(
      provider: "threads",
      id: obj["id"],
      author: obj["username"],
      content: (obj["caption"].to_s),
      created_at: (obj["timestamp"] ? Time.parse(obj["timestamp"]) : nil),
      url: (obj["permalink"].presence || obj["permalink_url"].presence),
      images: images
    )
  rescue => _e
    nil
  end

  # Batch-Details: /?ids=ID1,ID2&fields=...
  def fetch_threads_details_batch(conn, token, ids)
    resp = conn.get("/v1.0/", {
      access_token: token,
      ids: ids.join(','),
      fields: [
        'id',
        'permalink', 'permalink_url',
        'timestamp',
        'caption', 'username',
        'media_type', 'media_url', 'thumbnail_url',
        'children{media_type,media_url,thumbnail_url}'
      ].join(',')
    })
    return [] unless resp.success?
    parsed = JSON.parse(resp.body) rescue {}
    return [] unless parsed.is_a?(Hash)
    parsed.values.filter_map do |obj|
      next unless obj.is_a?(Hash)
      images = extract_threads_images(obj)
      Item.new(
        provider: "threads",
        id: obj["id"],
        author: obj["username"],
        content: (obj["caption"].to_s),
        created_at: (obj["timestamp"] ? Time.parse(obj["timestamp"]) : nil),
        url: (obj["permalink"].presence || obj["permalink_url"].presence),
        images: images
      )
    end
  rescue => _e
    []
  end

  def extract_threads_images(obj)
    if obj["media_url"] && (!obj["media_type"] || obj["media_type"].to_s.upcase.start_with?("IMAGE"))
      return [{ "url" => obj["media_url"], "alt" => "" }]
    end
    if obj["thumbnail_url"]
      return [{ "url" => obj["thumbnail_url"], "alt" => "" }]
    end
    if obj["image_url"]
      return [{ "url" => obj["image_url"], "alt" => "" }]
    end
    if obj["attachments"] && obj.dig("attachments","data").is_a?(Array)
      imgs = obj.dig("attachments","data").select { |a| (!a["media_type"] || a["media_type"].to_s.upcase.start_with?("IMAGE")) && (a["media_url"] || a["thumbnail_url"] || a["image_url"]).present? }
      return imgs.map { |a| { "url" => (a["media_url"] || a["thumbnail_url"] || a["image_url"]), "alt" => "" } } if imgs.any?
    end
    if obj["children"] && obj.dig("children","data").is_a?(Array)
      imgs = obj.dig("children","data").select { |a| (!a["media_type"] || a["media_type"].to_s.upcase.start_with?("IMAGE")) && (a["media_url"] || a["thumbnail_url"] || a["image_url"]).present? }
      return imgs.map { |a| { "url" => (a["media_url"] || a["thumbnail_url"] || a["image_url"]), "alt" => "" } } if imgs.any?
    end
    nil
  end
end



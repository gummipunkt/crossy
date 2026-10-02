require "faraday"
require "faraday/multipart"
require "json"
require "uri"

module Posting
  class MastodonClient < BaseClient
    MEDIA_POLL_INTERVAL = 2
    MEDIA_MAX_WAIT = 120

    def post!(post, media_attachments: [], idempotency_key: nil)
      base_url = @provider_account.instance.chomp("/")
      token = @provider_account.access_token
      raise "Missing access_token" if token.blank?

      body = { status: post.content_text }
      if post.content_warning.present?
        body[:spoiler_text] = post.content_warning.to_s
      end

      media_ids = Array(post.media_attachments).select { |ma| ma.file.attached? }.map do |ma|
        upload_media!(base_url, token, ma)
      end
      body[:media_ids] = media_ids if media_ids.any?

      resp = connection(base_url).post("/api/v1/statuses") do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Accept"] = "application/json"
        # Mastodon returns the original status for a repeated key, so a
        # retried delivery cannot create a duplicate post.
        req.headers["Idempotency-Key"] = idempotency_key if idempotency_key.present?
        req.options.timeout = 15
        req.options.open_timeout = 5
        req.body = body
      end

      unless resp.success?
        raise "Mastodon error: #{resp.status} #{resp.body}"
      end

      parsed = JSON.parse(resp.body) rescue {}
      parsed["id"] || raise("Mastodon response missing id: #{resp.body}")
    end

    private

    # /api/v2/media answers 202 while larger files (video, big images) are
    # still processing; attaching them before they are ready fails with 422.
    def upload_media!(base_url, token, ma)
      file = Faraday::Multipart::FilePart.new(StringIO.new(ma.file.download), ma.content_type, ma.filename)
      resp = upload_connection(base_url).post("/api/v2/media") do |req|
        req.headers["Authorization"] = "Bearer #{token}"
        req.headers["Accept"] = "application/json"
        req.body = { file: file, description: (ma.metadata || {})["alt"].to_s }
      end
      raise "Mastodon media error: #{resp.status} #{resp.body}" unless resp.success?

      media = (JSON.parse(resp.body) rescue {})
      id = media["id"] || raise("Mastodon media response missing id: #{resp.body}")
      wait_for_media!(base_url, token, id) if resp.status == 202 || media["url"].blank?
      id
    end

    def wait_for_media!(base_url, token, id)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MEDIA_MAX_WAIT
      loop do
        resp = connection(base_url).get("/api/v1/media/#{id}") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Accept"] = "application/json"
        end
        # 206 Partial Content means still processing.
        return if resp.status == 200
        raise "Mastodon media #{id} failed: #{resp.status} #{resp.body}" unless resp.status == 206
        raise "Mastodon media #{id} still processing after #{MEDIA_MAX_WAIT}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        pause(MEDIA_POLL_INTERVAL)
      end
    end

    def pause(seconds)
      sleep(seconds)
    end

    def upload_connection(base_url)
      SafeHttp.connection(base_url, request: { timeout: 60, open_timeout: 5 }) do |f|
        f.request :multipart
        f.request :url_encoded
      end
    end

    def connection(base_url)
      SafeHttp.connection(base_url) { |f| f.request :url_encoded }
    end
  end
end

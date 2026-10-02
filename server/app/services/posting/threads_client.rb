require "faraday"
require "json"
require "uri"

module Posting
  class ThreadsClient < BaseClient
    GRAPH_BASE = ENV.fetch("THREADS_GRAPH_BASE", "https://graph.threads.net")
    # Meta recommends waiting for the media container to finish processing
    # before publishing; text containers are usually ready immediately.
    CONTAINER_POLL_INTERVAL = 2
    CONTAINER_MAX_WAIT = 60

    # Text-Post und optional ein Bild (öffentlich erreichbar via PUBLIC_BASE_URL)
    def post!(post, media_attachments: [], idempotency_key: nil)
      access_token = ensure_fresh_token
      user_id = @provider_account.handle # in OAuth-Callback als me.id gespeichert
      raise "Missing access_token" if access_token.to_s.strip.empty?
      raise "Missing user id" if user_id.to_s.strip.empty?

      app_id = ENV.fetch("THREADS_APP_ID")
      conn = connection

      params = { access_token: access_token }

      if (image_url = first_public_image_url(post))
        params[:media_type] = "IMAGE"
        params[:image_url] = image_url
        params[:text] = post.content_text.to_s if post.content_text.present?
      else
        params[:media_type] = "TEXT"
        params[:text] = post.content_text.to_s
      end

      resp = conn.post("/v1.0/#{user_id}/threads") do |req|
        req.headers["Accept"] = "application/json"
        req.headers["X-IG-App-ID"] = app_id
        req.options.timeout = 15
        req.options.open_timeout = 5
        req.body = params
      end

      unless resp.success?
        # Auto‑Refresh bei Error 190
        if resp.status == 400 && resp.body.to_s.include?('"code":190')
          refresh = Faraday.get("#{GRAPH_BASE}/refresh_access_token", {
            grant_type: "th_refresh_token",
            access_token: access_token
          }, { "X-IG-App-ID" => app_id })
          if refresh.success?
            body = (JSON.parse(refresh.body) rescue {})
            new_token = body["access_token"]
            expires_in = body["expires_in"]
            if new_token.present?
              @provider_account.update!(access_token: new_token, threads_token_expires_at: (Time.now + expires_in.to_i rescue nil))
              params[:access_token] = new_token
              resp = conn.post("/v1.0/#{user_id}/threads") do |req|
                req.headers["Accept"] = "application/json"
                req.headers["X-IG-App-ID"] = app_id
                req.options.timeout = 15
                req.options.open_timeout = 5
                req.body = params
              end
            end
          end
        end
        raise "Threads error: #{resp.status} #{resp.body}" unless resp.success?
      end

      parsed = JSON.parse(resp.body) rescue {}
      creation_id = parsed["id"] || raise("Threads response missing id: #{resp.body}")

      # The token may have been refreshed above (error 190), so use the one
      # that actually created the container for the remaining calls.
      token = params[:access_token]
      wait_for_container!(conn, creation_id, token, app_id)

      publish_resp = conn.post("/v1.0/#{user_id}/threads_publish") do |req|
        req.headers["Accept"] = "application/json"
        req.headers["X-IG-App-ID"] = app_id
        req.options.timeout = 15
        req.options.open_timeout = 5
        req.body = { access_token: token, creation_id: creation_id }
      end
      raise "Threads publish failed: #{publish_resp.status} #{publish_resp.body}" unless publish_resp.success?

      # insights/replies endpoints require the published media id, not the container id.
      published_id = (JSON.parse(publish_resp.body) rescue {})["id"]
      raise "Threads publish response missing id: #{publish_resp.body}" if published_id.blank?

      published_id
    end

    private

    def connection
      Faraday.new(url: GRAPH_BASE) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end

    # Polls the container until Threads reports FINISHED. Raises on ERROR or
    # EXPIRED; after CONTAINER_MAX_WAIT the publish is attempted anyway and
    # Threads' own error decides.
    def wait_for_container!(conn, creation_id, token, app_id)
      deadline = monotonic_now + CONTAINER_MAX_WAIT
      loop do
        resp = conn.get("/v1.0/#{creation_id}") do |req|
          req.headers["Accept"] = "application/json"
          req.headers["X-IG-App-ID"] = app_id
          req.options.timeout = 15
          req.options.open_timeout = 5
          req.params = { access_token: token, fields: "status,error_message" }
        end
        if resp.success?
          body = (JSON.parse(resp.body) rescue {})
          case body["status"]
          when "FINISHED", "PUBLISHED" then return
          when "ERROR", "EXPIRED"
            raise "Threads container #{creation_id} #{body["status"]}: #{body["error_message"]}"
          end
        end
        return if monotonic_now >= deadline

        pause(CONTAINER_POLL_INTERVAL)
      end
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def pause(seconds)
      sleep(seconds)
    end

    def ensure_fresh_token
      token = @provider_account.access_token.to_s
      exp = @provider_account.threads_token_expires_at
      # Refresh 1 day before expiry if known
      # Refresh 3 Tage vor Ablauf (Long-lived sollten ~60 Tage halten)
      if exp && Time.now > (exp - 3.days)
        app_id = ENV.fetch("THREADS_APP_ID")
        refresh = Faraday.get(
          "#{GRAPH_BASE}/refresh_access_token",
          {
            grant_type: "th_refresh_token",
            access_token: token
          },
          {
            "X-IG-App-ID" => app_id
          }
        )
        if refresh.success?
          body = (JSON.parse(refresh.body) rescue {})
          new_token = body["access_token"]
          expires_in = body["expires_in"]
          if new_token.present?
            @provider_account.update!(access_token: new_token, threads_token_expires_at: ((Time.now + expires_in.to_i).utc rescue nil))
            return new_token
          end
        end
      end
      token
    end

    def first_public_image_url(post)
      ma = Array(post.media_attachments).find { |m| m.file.attached? && m.content_type.to_s.start_with?("image/") }
      return nil unless ma
      base = ENV["PUBLIC_BASE_URL"].to_s.presence
      return nil if base.blank?
      helpers = Rails.application.routes.url_helpers
      path = helpers.rails_blob_path(ma.file, only_path: true)
      URI.join(base, path).to_s
    end
  end
end

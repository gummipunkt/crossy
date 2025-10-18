require "faraday"
require "json"
require "uri"

module Posting
  class ThreadsClient < BaseClient
    GRAPH_BASE = ENV.fetch("THREADS_GRAPH_BASE", "https://graph.threads.net")

    # Text-Post und optional ein Bild (öffentlich erreichbar via PUBLIC_BASE_URL)
    def post!(post, media_attachments: [])
      access_token = ensure_fresh_token
      user_id = @provider_account.handle # in OAuth-Callback als me.id gespeichert
      raise "Missing access_token" if access_token.to_s.strip.empty?
      raise "Missing user id" if user_id.to_s.strip.empty?

      conn = Faraday.new(url: GRAPH_BASE) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end

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
          })
          if refresh.success?
            body = (JSON.parse(refresh.body) rescue {})
            new_token = body["access_token"]
            expires_in = body["expires_in"]
            if new_token.present?
              @provider_account.update!(access_token: new_token, threads_token_expires_at: (Time.now + expires_in.to_i rescue nil))
              params[:access_token] = new_token
              resp = conn.post("/v1.0/#{user_id}/threads") do |req|
                req.headers["Accept"] = "application/json"
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

      # Publish step: some Threads Graph flows require publishing the created container
      publish_ok = false
      publish_resp = nil
      begin
        # Preferred: explicit publish endpoint with creation_id
        publish_resp = conn.post("/v1.0/#{user_id}/threads_publish") do |req|
          req.headers["Accept"] = "application/json"
          req.options.timeout = 15
          req.options.open_timeout = 5
          req.body = { access_token: access_token, creation_id: creation_id }
        end
        publish_ok = publish_resp.success?
      rescue => _e
        publish_ok = false
      end

      unless publish_ok
        # Fallback: try toggling the container to published
        [
          { key: :published, value: true },
          { key: :is_published, value: true }
        ].each do |flag|
          begin
            publish_resp = conn.post("/v1.0/#{creation_id}") do |req|
              req.headers["Accept"] = "application/json"
              req.options.timeout = 15
              req.options.open_timeout = 5
              req.body = { access_token: access_token, flag[:key] => flag[:value] }
            end
            if publish_resp.success?
              publish_ok = true
              break
            end
          rescue => _e
            # continue to next fallback
          end
        end
      end

      unless publish_ok
        Rails.logger.warn("Threads publish step failed for creation_id=#{creation_id}: #{publish_resp&.status} #{publish_resp&.body}")
      end

      creation_id
    end

    private
    def ensure_fresh_token
      token = @provider_account.access_token.to_s
      exp = @provider_account.threads_token_expires_at
      # Refresh 1 day before expiry if known
      # Refresh 3 Tage vor Ablauf (Long-lived sollten ~60 Tage halten)
      if exp && Time.now > (exp - 3.days)
        refresh = Faraday.get("#{GRAPH_BASE}/refresh_access_token", {
          grant_type: "th_refresh_token",
          access_token: token
        })
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



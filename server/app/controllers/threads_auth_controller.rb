require "uri"

class ThreadsAuthController < ApplicationController
  # Callback darf ohne Login laufen, Start der OAuth-Flow erfordert Login
  skip_before_action :authenticate_user!, only: [:callback]
  def new
    app_id = ENV.fetch("THREADS_APP_ID")
    redirect_uri = callback_url
    state = SecureRandom.hex(16)
    session[:threads_oauth_state] = state
    scope = %w[threads_basic threads_content_publish].join(",")
    oauth_base = ENV.fetch("THREADS_OAUTH_BASE", "https://www.threads.net")
    # Safety: Some deployments mistakenly set threads.com which requires headers we can't send via browser
    begin
      ob = URI.parse(oauth_base)
      if ob.host&.end_with?("threads.com")
        oauth_base = "https://www.threads.net"
      end
    rescue
      oauth_base = "https://www.threads.net"
    end
    # Sende sowohl client_id als auch app_id, da einige Threads-Frontends app_id erwarten
    url = "#{oauth_base}/oauth/authorize?client_id=#{CGI.escape(app_id)}&app_id=#{CGI.escape(app_id)}&redirect_uri=#{CGI.escape(redirect_uri)}&response_type=code&scope=#{CGI.escape(scope)}&state=#{state}"
    redirect_to url, allow_other_host: true
  end

  def callback
    if params[:state] != session.delete(:threads_oauth_state)
      return redirect_to new_post_path, alert: "Invalid OAuth State"
    end

    code = params[:code]
    app_id = ENV.fetch("THREADS_APP_ID")
    app_secret = ENV.fetch("THREADS_APP_SECRET")
    redirect_uri = callback_url

    # 1) Get short-lived token
    graph_base = ENV.fetch("THREADS_GRAPH_BASE", "https://graph.threads.net")
    token_resp = Faraday.post("#{graph_base}/oauth/access_token", {
      client_id: app_id,
      client_secret: app_secret,
      redirect_uri: redirect_uri,
      code: code,
      grant_type: "authorization_code"
    }, { "X-IG-App-ID" => app_id })
    unless token_resp.success?
      return redirect_to new_post_path, alert: "Threads Tokenfehler: #{token_resp.status}"
    end
    token_json = JSON.parse(token_resp.body) rescue {}
    short_token = token_json["access_token"]

    # 2) Exchange short-lived to long-lived token (GET /access_token)
    exchange_resp = Faraday.get("#{graph_base}/access_token", {
      grant_type: "th_exchange_token",
      client_secret: app_secret,
      access_token: short_token
    }, { "X-IG-App-ID" => app_id })

    access_token = nil
    expires_in = nil
    if exchange_resp.success?
      exchange_json = JSON.parse(exchange_resp.body) rescue {}
      access_token = exchange_json["access_token"]
      expires_in   = exchange_json["expires_in"]
    else
      # Fallback: Try refresh
      refresh_resp = Faraday.get("#{graph_base}/refresh_access_token", {
        grant_type: "th_refresh_token",
        access_token: short_token
      }, { "X-IG-App-ID" => app_id })
      if refresh_resp.success?
        refresh_json = JSON.parse(refresh_resp.body) rescue {}
        access_token = refresh_json["access_token"]
        expires_in   = refresh_json["expires_in"]
      else
        # Last fallback: use short-lived token (not ideal)
        access_token = short_token
      end
    end

    # If token still short-lived (~1h), try to refresh once
    if expires_in.nil? || expires_in.to_i <= 3600
      refresh_resp2 = Faraday.get("#{graph_base}/refresh_access_token", {
        grant_type: "th_refresh_token",
        access_token: access_token
      }, { "X-IG-App-ID" => app_id })
      if refresh_resp2.success?
        rj = JSON.parse(refresh_resp2.body) rescue {}
        access_token = rj["access_token"] || access_token
        expires_in   = rj["expires_in"] || expires_in
      end
    end

    me_resp = Faraday.get("#{graph_base}/v1.0/me", { access_token: access_token }, { "X-IG-App-ID" => app_id })
    unless me_resp.success?
      return redirect_to new_post_path, alert: "Threads /me Fehler: #{me_resp.status}"
    end
    me = JSON.parse(me_resp.body) rescue {}
    user_id = me["id"]

    unless current_user
      return redirect_to new_user_session_path, alert: "Please sign in first"
    end
    pa = current_user.provider_accounts.find_or_create_by!(provider: "threads", handle: user_id)
    # Save long-lived token and expiration if available
    attrs = { access_token: access_token }
    attrs[:threads_token_expires_at] = (Time.now + expires_in.to_i).utc if expires_in
    pa.update!(attrs)

    redirect_to new_post_path, notice: "Threads connected as #{user_id}"
  end

  private

  def callback_url
    # Prefer current request host to preserve session cookies; fallback to PUBLIC_BASE_URL
    base = request.base_url.presence || ENV["PUBLIC_BASE_URL"].presence || "http://localhost:3000"
    URI.join(base, "/auth/threads/callback").to_s
  end
end



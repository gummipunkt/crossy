class ThreadsAuthController < ApplicationController
  def new
    app_id = ENV.fetch("THREADS_APP_ID")
    redirect_uri = callback_url
    state = SecureRandom.hex(16)
    session[:threads_oauth_state] = state
    scope = %w[threads_basic threads_content_publish].join(",")
    url = "https://www.threads.net/oauth/authorize?client_id=#{CGI.escape(app_id)}&redirect_uri=#{CGI.escape(redirect_uri)}&response_type=code&scope=#{CGI.escape(scope)}&state=#{state}"
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
    token_resp = Faraday.post("https://graph.threads.net/oauth/access_token", {
      client_id: app_id,
      client_secret: app_secret,
      redirect_uri: redirect_uri,
      code: code,
      grant_type: "authorization_code"
    })
    unless token_resp.success?
      return redirect_to new_post_path, alert: "Threads Tokenfehler: #{token_resp.status}"
    end
    token_json = JSON.parse(token_resp.body) rescue {}
    short_token = token_json["access_token"]

    # 2) Change to long-lived token (POST, with client_token if available)
    client_token = ENV["THREADS_CLIENT_TOKEN"].to_s.presence
    exchange_params = {
      grant_type: "th_exchange_token",
      client_secret: app_secret,
      access_token: short_token
    }
    exchange_params[:client_token] = client_token if client_token

    exchange_resp = Faraday.post("https://graph.threads.net/oauth/access_token", exchange_params)

    access_token = nil
    expires_in = nil
    if exchange_resp.success?
      exchange_json = JSON.parse(exchange_resp.body) rescue {}
      access_token = exchange_json["access_token"]
      expires_in   = exchange_json["expires_in"]
    else
      # Fallback: Try refresh
      refresh_resp = Faraday.get("https://graph.threads.net/refresh_access_token", {
        grant_type: "th_refresh_token",
        access_token: short_token
      })
      if refresh_resp.success?
        refresh_json = JSON.parse(refresh_resp.body) rescue {}
        access_token = refresh_json["access_token"]
        expires_in   = refresh_json["expires_in"]
      else
        # Last fallback: use short-lived token (not ideal)
        access_token = short_token
      end
    end

    me_resp = Faraday.get("https://graph.threads.net/v1.0/me", { access_token: access_token })
    unless me_resp.success?
      return redirect_to new_post_path, alert: "Threads /me Fehler: #{me_resp.status}"
    end
    me = JSON.parse(me_resp.body) rescue {}
    user_id = me["id"]

    pa = ProviderAccount.find_or_create_by!(provider: "threads", handle: user_id)
    # Optional: Save expiration if available
    attrs = { access_token: access_token }
    attrs[:threads_token_expires_at] = Time.now + expires_in.to_i if expires_in
    pa.update!(attrs)

    redirect_to new_post_path, notice: "Threads connected as #{user_id}"
  end

  private

  def callback_url
    # PUBLIC_BASE_URL for ngrok; fallback to localhost
    base = ENV["PUBLIC_BASE_URL"].presence || "http://localhost:3000"
    URI.join(base, "/auth/threads/callback").to_s
  end
end



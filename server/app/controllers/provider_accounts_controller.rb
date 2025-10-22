class ProviderAccountsController < ApplicationController
  def index
    @provider_accounts = ProviderAccount.where(user_id: current_user.id).order(:provider, :handle)
  end

  def new
  end

  def create
    provider = params.require(:provider)

    case provider
    when "mastodon"
      handle = params.require(:handle)
      instance = params.require(:instance).to_s.strip
      token = params.require(:access_token).to_s.strip

      # Normalisiere Instanz ähnlich zum Model-Callback
      unless instance.start_with?("http://", "https://")
        instance = "https://#{instance}"
      end
      instance = instance.sub(%r{/+$}, "")

      # Validiere Token gegen Instanz
      conn = Faraday.new(url: instance) { |f| f.adapter Faraday.default_adapter }
      verify = conn.get("/api/v1/accounts/verify_credentials") do |r|
        r.headers["Authorization"] = "Bearer #{token}"
        r.headers["Accept"] = "application/json"
      end
      unless verify.success?
        raise "Mastodon-Token ungültig (#{verify.status}): #{verify.body}"
      end

      # Versuche Scopes zu ermitteln und auf write:statuses zu prüfen
      scopes_string = nil
      begin
        info = conn.get("/oauth/token/info") do |r|
          r.headers["Authorization"] = "Bearer #{token}"
          r.headers["Accept"] = "application/json"
        end
        if info.success?
          body = (JSON.parse(info.body) rescue {})
          raw_scopes = body["scopes"]
          scopes = raw_scopes.is_a?(Array) ? raw_scopes : raw_scopes.to_s.split(/\s+/)
          scopes_string = scopes.join(" ")
          unless scopes.include?("write:statuses")
            raise "Mastodon-Token: erforderlicher Scope fehlt: write:statuses"
          end
        end
      rescue => _e
        # Einige Server haben kein /oauth/token/info – in dem Fall fahren wir fort,
        # aber speichern keine Scopes.
        scopes_string ||= nil
      end

      pa = ProviderAccount.create!(
        provider: "mastodon",
        handle: handle,
        instance: instance,
        access_token: token,
        scopes: scopes_string,
        user_id: current_user.id
      )
      redirect_to provider_accounts_path, notice: "Mastodon verbunden: #{pa.handle}"

    when "bluesky"
      pa = ProviderAccount.find_or_create_by!(
        provider: "bluesky",
        handle: params.require(:handle),
        instance: params[:instance].presence,
        user_id: current_user.id
      )
      Posting::BlueskyClient.new(pa).login!(params.require(:app_password))
      redirect_to provider_accounts_path, notice: "Bluesky connected: #{pa.handle}"

    when "nostr"
      pa = ProviderAccount.create!(
        provider: "nostr",
        handle: params.require(:handle),
        public_key: params.require(:public_key),
        user_id: current_user.id
      )
      redirect_to provider_accounts_path, notice: "Nostr connected: #{pa.handle}"

    when "threads"
      redirect_to "/auth/threads"

    else
      redirect_to provider_accounts_path, alert: "Unknown provider"
    end
  rescue => e
    redirect_to provider_accounts_path, alert: e.message
  end

  def destroy
    pa = ProviderAccount.where(user_id: current_user.id).find(params[:id])
    pa.destroy!
    redirect_to provider_accounts_path, notice: "Channel removed"
  end
end



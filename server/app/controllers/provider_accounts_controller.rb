class ProviderAccountsController < ApplicationController
  def index
    @provider_accounts = ProviderAccount.where(user_id: current_user.id).order(:provider, :handle)
  end

  def new
  end

  def create
    connector = ProviderConnector.new(current_user)

    case params.require(:provider)
    when "mastodon"
      pa = connector.mastodon!(
        handle: params.require(:handle),
        instance: params.require(:instance),
        access_token: params.require(:access_token)
      )
      redirect_to provider_accounts_path, notice: "Mastodon connected: #{pa.handle}"
    when "bluesky"
      pa = connector.bluesky!(
        handle: params.require(:handle),
        app_password: params.require(:app_password),
        instance: params[:instance]
      )
      redirect_to provider_accounts_path, notice: "Bluesky connected: #{pa.handle}"
    when "nostr"
      pa = connector.nostr!(handle: params.require(:handle), public_key: params.require(:public_key))
      redirect_to provider_accounts_path, notice: "Nostr connected: #{pa.handle}"
    when "threads"
      redirect_to "/auth/threads"
    else
      redirect_to provider_accounts_path, alert: "Unknown provider"
    end
  rescue => e
    # Remote error bodies can be long; keep the flash well below the cookie limit.
    redirect_to provider_accounts_path, alert: e.message.truncate(300)
  end

  def destroy
    pa = ProviderAccount.where(user_id: current_user.id).find(params[:id])
    pa.destroy!
    redirect_to provider_accounts_path, notice: "Channel removed"
  end
end

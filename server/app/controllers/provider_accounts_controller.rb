class ProviderAccountsController < ApplicationController
  def index
    @provider_accounts = ProviderAccount.order(:provider, :handle)
  end

  def new
  end

  def create
    provider = params.require(:provider)

    case provider
    when "mastodon"
      pa = ProviderAccount.create!(
        provider: "mastodon",
        handle: params.require(:handle),
        instance: params.require(:instance),
        access_token: params.require(:access_token)
      )
      redirect_to provider_accounts_path, notice: "Mastodon connected: #{pa.handle}"

    when "bluesky"
      pa = ProviderAccount.find_or_create_by!(
        provider: "bluesky",
        handle: params.require(:handle),
        instance: params[:instance].presence
      )
      Posting::BlueskyClient.new(pa).login!(params.require(:app_password))
      redirect_to provider_accounts_path, notice: "Bluesky connected: #{pa.handle}"

    when "nostr"
      pa = ProviderAccount.create!(
        provider: "nostr",
        handle: params.require(:handle),
        public_key: params.require(:public_key)
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
    pa = ProviderAccount.find(params[:id])
    pa.destroy!
    redirect_to provider_accounts_path, notice: "Channel removed"
  end
end



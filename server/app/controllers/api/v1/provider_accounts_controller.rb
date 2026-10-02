module Api
  module V1
    class ProviderAccountsController < BaseController
      def index
        accounts = current_user.provider_accounts.order(:provider, :handle)
        render json: { provider_accounts: accounts.map { |pa| account_payload(pa) } }
      end

      def create
        provider = params.require(:provider).to_s

        case provider
        when "mastodon" then create_mastodon
        when "bluesky"  then create_bluesky
        when "nostr"    then create_nostr
        when "threads"
          render json: { error: "Threads must be connected via the browser OAuth flow at /auth/threads" }, status: :bad_request
        else
          render json: { error: "Unknown provider" }, status: :bad_request
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def destroy
        pa = current_user.provider_accounts.find(params[:id])
        pa.destroy!
        head :no_content
      end

      private

      def account_payload(pa)
        {
          id: pa.id,
          provider: pa.provider,
          handle: pa.handle,
          instance: pa.instance,
          status: pa.status,
          created_at: pa.created_at.iso8601
        }
      end

      def create_mastodon
        pa = connector.mastodon!(
          handle: params.require(:handle),
          instance: params.require(:instance),
          access_token: params.require(:access_token)
        )
        render json: { provider_account: account_payload(pa) }, status: :created
      end

      def create_bluesky
        pa = connector.bluesky!(
          handle: params.require(:handle),
          app_password: params.require(:app_password),
          instance: params[:instance]
        )
        render json: { provider_account: account_payload(pa) }, status: :created
      end

      def create_nostr
        pa = connector.nostr!(handle: params.require(:handle), public_key: params.require(:public_key))
        render json: { provider_account: account_payload(pa) }, status: :created
      end

      def connector
        ProviderConnector.new(current_user)
      end
    end
  end
end

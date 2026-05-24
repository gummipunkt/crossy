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
        handle   = params.require(:handle).to_s.strip
        instance = params.require(:instance).to_s.strip
        token    = params.require(:access_token).to_s.strip

        instance = "https://#{instance}" unless instance.start_with?("http://", "https://")
        instance = instance.sub(%r{/+$}, "")
        SsrfSafeUrlValidator.validate!(instance)

        conn = Faraday.new(url: instance) { |f| f.adapter Faraday.default_adapter }
        verify = conn.get("/api/v1/accounts/verify_credentials") do |r|
          r.headers["Authorization"] = "Bearer #{token}"
          r.headers["Accept"] = "application/json"
        end
        raise "Mastodon token invalid (#{verify.status})" unless verify.success?

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
            raise "Mastodon token missing scope: write:statuses" unless scopes.include?("write:statuses")
          end
        rescue => e
          raise e if e.message.include?("missing scope")
          scopes_string ||= nil
        end

        pa = current_user.provider_accounts.create!(
          provider: "mastodon",
          handle: handle,
          instance: instance,
          access_token: token,
          scopes: scopes_string
        )
        render json: { provider_account: account_payload(pa) }, status: :created
      end

      def create_bluesky
        handle       = params.require(:handle).to_s.strip
        app_password = params.require(:app_password).to_s
        instance     = params[:instance].presence&.to_s&.strip

        if instance.present?
          instance = "https://#{instance}" unless instance.start_with?("http://", "https://")
          instance = instance.sub(%r{/+$}, "")
          SsrfSafeUrlValidator.validate!(instance)
        end

        pa = ProviderAccount.find_or_create_by!(
          provider: "bluesky",
          handle: handle,
          instance: instance.presence,
          user_id: current_user.id
        )
        Posting::BlueskyClient.new(pa).login!(app_password)
        render json: { provider_account: account_payload(pa) }, status: :created
      end

      def create_nostr
        pa = current_user.provider_accounts.create!(
          provider: "nostr",
          handle: params.require(:handle),
          public_key: params.require(:public_key)
        )
        render json: { provider_account: account_payload(pa) }, status: :created
      end
    end
  end
end

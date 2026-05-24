module Api
  module V1
    class BaseController < ActionController::Base
      include Devise::Controllers::Helpers

      protect_from_forgery with: :null_session

      before_action :authenticate_api_user!

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActionController::ParameterMissing, with: :parameter_missing
      rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

      attr_reader :current_api_token

      private

      def authenticate_api_user!
        if (token = extract_bearer_token)
          api_token = ApiToken.authenticate(token)
          if api_token
            @current_api_token = api_token
            sign_in(api_token.user, store: false)
            return
          end
          render json: { error: "Invalid or revoked token" }, status: :unauthorized
          return
        end

        # Cookie/session-based fallback (existing browser callers, e.g. Nostr JS)
        unless user_signed_in?
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def extract_bearer_token
        header = request.headers["Authorization"].to_s
        return nil unless header.start_with?("Bearer ")

        header.split(" ", 2).last&.strip
      end

      def record_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def parameter_missing(e)
        render json: { error: "Missing parameter: #{e.param}" }, status: :bad_request
      end

      def record_invalid(e)
        render json: { error: "Invalid record", details: e.record.errors.as_json }, status: :unprocessable_entity
      end
    end
  end
end

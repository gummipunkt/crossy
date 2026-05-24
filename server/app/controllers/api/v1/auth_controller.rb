module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_api_user!, only: [ :sign_in ]

      def sign_in
        email    = params.require(:email).to_s.strip.downcase
        password = params.require(:password).to_s
        device   = params[:device_label].presence

        user = User.find_by(email: email)
        if user&.valid_password?(password)
          token = ApiToken.issue!(user: user, device_label: device)
          render json: {
            token: token.raw_token,
            token_id: token.id,
            user: user_payload(user)
          }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def sign_out
        current_api_token&.revoke!
        head :no_content
      end

      def me
        render json: { user: user_payload(current_user) }
      end

      private

      def user_payload(user)
        {
          id: user.id,
          email: user.email,
          display_name: user.try(:display_name),
          admin: user.try(:admin) == true
        }
      end
    end
  end
end

module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

      private

      def record_not_found
        render json: { error: "Not found" }, status: :not_found
      end
    end
  end
end

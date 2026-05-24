module Api
  module V1
    class PostsController < BaseController
      def index
        posts = current_user.posts.order(created_at: :desc).limit(50)
        render json: { posts: posts.map { |p| post_payload(p) } }
      end

      def create
        post = current_user.posts.create!(
          content_text: params.require(:content_text),
          content_warning: params[:content_warning],
          media_slots: parse_media_slots
        )

        attach_media(post)

        provider_ids = Array(params[:provider_account_ids]).reject(&:blank?)
        provider_accounts = current_user.provider_accounts.where(id: provider_ids)

        deliveries = provider_accounts.map do |pa|
          Delivery.create!(post: post, provider_account: pa, status: "queued", dedup_key: SecureRandom.uuid)
        end

        deliveries.each { |d| PostDeliveryJob.perform_later(d.id) }

        render json: {
          id: post.id,
          content_text: post.content_text,
          deliveries: deliveries.map { |d| delivery_payload(d) }
        }, status: :accepted
      end

      def show
        post = current_user.posts.find(params[:id])
        render json: post_payload(post).merge(
          deliveries: post.deliveries.includes(:provider_account).map { |d| delivery_payload(d) }
        )
      end

      private

      def attach_media(post)
        files = Array(params[:files])
        alts_param = params[:alts]
        alts =
          if alts_param.is_a?(Array)
            alts_param
          else
            alts_param.to_s.split(/\r?\n/)
          end

        files.each_with_index do |uploaded, idx|
          next unless uploaded.respond_to?(:original_filename)
          ma = post.media_attachments.create!(
            filename: uploaded.original_filename,
            content_type: uploaded.content_type || "application/octet-stream",
            byte_size: uploaded.size,
            metadata: { alt: alts[idx].to_s }
          )
          ma.file.attach(uploaded)
        end
      end

      def parse_media_slots
        slots = params[:media_slots]
        return [] if slots.blank?
        slots.is_a?(String) ? (JSON.parse(slots) rescue []) : slots
      end

      def post_payload(post)
        {
          id: post.id,
          content_text: post.content_text,
          content_warning: post.content_warning,
          created_at: post.created_at.iso8601
        }
      end

      def delivery_payload(d)
        {
          id: d.id,
          provider: d.provider_account.provider,
          handle: d.provider_account.handle,
          status: d.status,
          provider_post_id: d.provider_post_id,
          error_message: d.error_message
        }
      end
    end
  end
end

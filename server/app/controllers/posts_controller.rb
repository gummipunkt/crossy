class PostsController < ApplicationController
  def new
    @post = Post.new
    load_provider_accounts
  end

  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      # Create media (optional)
      files = Array(params[:files])
      alts = Array(params[:alts].to_s.split(/\r?\n/))
      files.each_with_index do |uploaded, idx|
        next unless uploaded.respond_to?(:original_filename)
        ma = @post.media_attachments.create!(
          filename: uploaded.original_filename,
          content_type: uploaded.content_type || "application/octet-stream",
          byte_size: uploaded.size,
          metadata: { alt: alts[idx].to_s }
        )
        ma.file.attach(uploaded)
      end

      provider_ids = Array(params[:provider_account_ids]).reject(&:blank?)
      provider_accounts = ProviderAccount.where(user_id: current_user.id, id: provider_ids)

      deliveries = provider_accounts.map do |pa|
        Delivery.create!(post: @post, provider_account: pa, status: Delivery.initial_status_for(pa, @post), dedup_key: SecureRandom.uuid)
      end

      deliveries.select(&:queued?).each { |d| PostDeliveryJob.perform_later(d.id) }

      notice =
        if @post.scheduled_for_later?
          "Post scheduled for #{l(@post.scheduled_at, format: :long)} UTC to #{deliveries.size} network(s)"
        else
          "Post queued for #{deliveries.size} network(s)"
        end
      redirect_to @post, notice: notice
    else
      load_provider_accounts
      flash.now[:alert] = @post.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  # Sends a scheduled post right away.
  def publish_now
    @post = current_user.posts.find(params[:id])
    @post.update!(scheduled_at: Time.current) if @post.scheduled_for_later?
    count = Delivery.dispatch_due!(@post.deliveries)
    redirect_to @post, notice: "Publishing now to #{count} network(s)"
  end

  # Stops scheduled deliveries; they can still be sent later with "Retry".
  def cancel_schedule
    @post = current_user.posts.find(params[:id])
    count = @post.deliveries.scheduled.update_all(status: "failed", error_message: "Cancelled", finished_at: Time.current, updated_at: Time.current)
    @post.update!(scheduled_at: nil)
    redirect_to @post, notice: "Cancelled #{count} scheduled delivery(ies)"
  end

  def show
    @post = current_user.posts.find(params[:id])
    @deliveries = @post.deliveries.includes(:provider_account, :replies)
    @nostr_accounts = current_user.provider_accounts.where(provider: "nostr").order(:handle)

    Delivery.enqueue_stale_engagement_syncs(@deliveries)
  end

  def deliveries
    @post = current_user.posts.find(params[:id])
    @deliveries = @post.deliveries.includes(:provider_account, :replies)
    render inline: <<~ERB, locals: { post: @post, deliveries: @deliveries }
      <turbo-frame id="<%= dom_id(post, :deliveries) %>">
        <%= render partial: "deliveries", locals: { post: post, deliveries: deliveries } %>
      </turbo-frame>
    ERB
  end

  def refresh_engagement
    @post = current_user.posts.find(params[:id])
    deliveries = @post.deliveries.includes(:provider_account).select(&:engagement_syncable?)
    deliveries.each { |d| SyncDeliveryEngagementJob.perform_later(d.id) }
    redirect_to @post, notice: "Engagement-Sync für #{deliveries.size} Netzwerk(e) gestartet."
  end

  private

  def post_params
    params.require(:post).permit(:content_text, :content_warning, :scheduled_at)
  end

  # Only the current user's channels; hide duplicates (same provider/handle/instance)
  def load_provider_accounts
    scope = ProviderAccount.where(user_id: current_user.id)
    @provider_accounts = scope.order(:provider, :handle).to_a.uniq { |pa| [ pa.provider, pa.handle, pa.instance.to_s ] }
  end
end

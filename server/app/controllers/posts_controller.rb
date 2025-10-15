class PostsController < ApplicationController
  def new
    @post = Post.new
    # Hide duplicate entries (same provider/handle/instance) in the selection
    @provider_accounts = ProviderAccount.order(:provider, :handle).to_a.uniq { |pa| [pa.provider, pa.handle, pa.instance.to_s] }
  end

  def create
    @post = Post.new(post_params)
    if @post.save
      # Create media (optional)
      files = Array(params[:files])
      alts = Array(params[:alts].to_s.split(/\r?\n/))
      files.each_with_index do |uploaded, idx|
        next unless uploaded.respond_to?(:original_filename)
        ma = @post.media_attachments.create!(
          filename: uploaded.original_filename,
          content_type: uploaded.content_type || 'application/octet-stream',
          byte_size: uploaded.size,
          metadata: { alt: alts[idx].to_s }
        )
        ma.file.attach(uploaded)
      end

      provider_ids = Array(params[:provider_account_ids]).reject(&:blank?)
      provider_accounts = ProviderAccount.where(id: provider_ids)

      deliveries = provider_accounts.map do |pa|
        Delivery.create!(post: @post, provider_account: pa, status: "queued", dedup_key: SecureRandom.uuid)
      end

      deliveries.each { |d| PostDeliveryJob.perform_later(d.id) }

      redirect_to @post, notice: "Post planed to (#{deliveries.size} network(s)"
    else
      @provider_accounts = ProviderAccount.order(:provider, :handle)
      flash.now[:alert] = "Please enter text"
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @post = Post.find(params[:id])
    @deliveries = @post.deliveries.includes(:provider_account)
    @nostr_accounts = ProviderAccount.where(provider: "nostr").order(:handle)
  end

  private

  def post_params
    params.require(:post).permit(:content_text, :content_warning)
  end
end



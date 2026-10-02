class DeliveriesController < ApplicationController
  # POST /posts/:post_id/deliveries/:id/retry
  def redeliver
    post = current_user.posts.find(params[:post_id])
    delivery = post.deliveries.find(params[:id])

    if delivery.retry!
      redirect_to post, notice: "#{helpers.network_label(delivery.provider_account.provider)}: delivery queued again"
    else
      redirect_to post, alert: "Only failed deliveries can be retried"
    end
  end
end

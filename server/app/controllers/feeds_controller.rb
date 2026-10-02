class FeedsController < ApplicationController
  def index
    @items = FeedAggregator.new.aggregate(limit: 50, user: current_user)
  end

  def interact
    ok = FeedInteraction.new(current_user).perform!(
      provider: params.require(:provider),
      item_id: params.require(:id),
      action: params.require(:action_type),
      cid: params[:cid],
      provider_account_id: params[:provider_account_id]
    )
    head(ok ? :ok : :unprocessable_entity)
  rescue FeedInteraction::UnsupportedAction
    head :bad_request
  rescue => e
    Rails.logger.error("Timeline action error: #{e.message}")
    head :unprocessable_entity
  end
end

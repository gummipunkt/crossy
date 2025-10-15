class TimelineController < ApplicationController
  def index
    @posts = Post.includes(deliveries: :provider_account).order(created_at: :desc).limit(100)
  end
end



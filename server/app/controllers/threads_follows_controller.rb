class ThreadsFollowsController < ApplicationController
  before_action :authenticate_user!

  def create
    pa = current_user.provider_accounts.where(provider: "threads").find(params.require(:provider_account_id))

    raw = params.require(:username).to_s
    usernames = raw.split(/[\s,]+/).map { |u| u.strip.delete_prefix("@") }.reject(&:blank?)

    if usernames.empty?
      redirect_to provider_accounts_path, alert: "No usernames provided" and return
    end

    created = 0
    skipped = []
    usernames.each do |u|
      tf = pa.threads_follows.build(username: u)
      if tf.save
        created += 1
      else
        skipped << u
      end
    end

    notice = "Following #{created} Threads account#{'s' if created != 1}."
    notice += " Skipped: #{skipped.join(', ')}." if skipped.any?
    redirect_to provider_accounts_path, notice: notice
  rescue ActiveRecord::RecordNotFound
    redirect_to provider_accounts_path, alert: "Threads account not found"
  end

  def destroy
    tf = ThreadsFollow.joins(:provider_account)
                      .where(provider_accounts: { user_id: current_user.id })
                      .find(params[:id])
    tf.destroy!
    redirect_to provider_accounts_path, notice: "Unfollowed @#{tf.username}"
  end
end

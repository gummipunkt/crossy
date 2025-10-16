class Admin::UsersController < Admin::BaseController
  def index
    @users = User.left_joins(:provider_accounts)
                 .select('users.*, COUNT(provider_accounts.id) AS networks_count')
                 .group('users.id')
                 .order('users.created_at DESC')
  end

  def show
    @user = User.find(params[:id])
    @accounts = @user.provider_accounts.order(:provider, :handle)
  end

  def destroy
    user = User.find(params[:id])
    if user == current_user
      redirect_to admin_users_path, alert: "You cannot delete yourself"
    else
      user.destroy!
      redirect_to admin_users_path, notice: "User deleted"
    end
  end

  def make_admin
    user = User.find(params[:id])
    user.update!(admin: true)
    redirect_to admin_users_path, notice: "User promoted to admin"
  end
end



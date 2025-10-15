class AddUserToPostsAndScope < ActiveRecord::Migration[8.0]
  def change
    add_reference :posts, :user, foreign_key: true, null: true
    add_reference :provider_accounts, :user, foreign_key: true, null: true unless column_exists?(:provider_accounts, :user_id)
  end
end



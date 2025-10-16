class AddThreadsExpiresAtToProviderAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :provider_accounts, :threads_token_expires_at, :datetime
    add_index :provider_accounts, :threads_token_expires_at
  end
end



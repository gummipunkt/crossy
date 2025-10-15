class AddEncryptedTokensToProviderAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :provider_accounts, :access_token_ciphertext, :text
    add_column :provider_accounts, :refresh_token_ciphertext, :text
    add_column :provider_accounts, :handle_bidx, :string
    add_index :provider_accounts, :handle_bidx
  end
end

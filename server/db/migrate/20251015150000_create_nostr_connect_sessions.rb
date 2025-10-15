class CreateNostrConnectSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :nostr_connect_sessions do |t|
      t.references :provider_account, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :app_public_key, null: false
      t.text :app_private_key_enc
      t.text :relay_secret_enc
      t.text :relays_json, null: false, default: "[]"
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :nostr_connect_sessions, [:provider_account_id, :status]
  end
end



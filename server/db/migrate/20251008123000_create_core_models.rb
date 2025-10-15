class CreateCoreModels < ActiveRecord::Migration[7.1]
  def change
    create_table :provider_accounts do |t|
      t.string :provider, null: false
      t.string :handle, null: false
      t.string :instance
      t.text :scopes
      t.string :status, null: false, default: "active"
      t.string :public_key
      t.text :private_key_enc
      t.references :user, foreign_key: true, null: true
      t.timestamps
    end
    add_index :provider_accounts, [:provider, :handle, :instance], unique: true, name: "idx_provider_accounts_identity"

    create_table :posts do |t|
      t.text :content_text, null: false
      t.text :content_warning
      t.jsonb :media_slots, null: false, default: []
      t.datetime :scheduled_at
      t.timestamps
    end

    create_table :deliveries do |t|
      t.references :post, null: false, foreign_key: true
      t.references :provider_account, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :provider_post_id
      t.text :error_message
      t.string :dedup_key
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :deliveries, [:post_id, :provider_account_id], unique: true
    add_index :deliveries, :dedup_key, unique: true

    create_table :media_attachments do |t|
      t.references :post, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type, null: false
      t.integer :byte_size
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
  end
end



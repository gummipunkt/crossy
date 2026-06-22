class CreateThreadsFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :threads_follows do |t|
      t.references :provider_account, null: false, foreign_key: true
      t.string :username, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_polled_at
      t.datetime :last_seen_post_at
      t.timestamps
    end

    add_index :threads_follows,
              [ :provider_account_id, :username ],
              unique: true,
              name: "idx_threads_follows_on_account_and_username"
  end
end

class AddEngagementTracking < ActiveRecord::Migration[7.1]
  def change
    add_column :deliveries, :like_count, :integer, default: 0, null: false
    add_column :deliveries, :reply_count, :integer, default: 0, null: false
    add_column :deliveries, :repost_count, :integer, default: 0, null: false
    add_column :deliveries, :metrics_fetched_at, :datetime
    add_column :deliveries, :metrics_error, :text

    create_table :delivery_replies do |t|
      t.references :delivery, null: false, foreign_key: true
      t.string :remote_id, null: false
      t.string :author_handle
      t.string :author_name
      t.string :author_avatar_url
      t.text :content
      t.datetime :posted_at
      t.string :permalink
      t.timestamps
    end
    add_index :delivery_replies, [ :delivery_id, :remote_id ], unique: true
    add_index :delivery_replies, :posted_at
  end
end

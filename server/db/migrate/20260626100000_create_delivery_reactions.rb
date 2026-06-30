class CreateDeliveryReactions < ActiveRecord::Migration[7.1]
  def change
    create_table :delivery_reactions do |t|
      t.references :delivery, null: false, foreign_key: true
      t.string :kind, null: false # "like" or "repost"
      t.string :remote_id, null: false # author identifier on the network (account id / DID)
      t.string :author_handle
      t.string :author_name
      t.string :author_avatar_url
      t.string :author_url
      t.datetime :reacted_at
      t.timestamps
    end
    add_index :delivery_reactions, [ :delivery_id, :kind, :remote_id ], unique: true,
              name: "idx_reactions_delivery_kind_remote"
    add_index :delivery_reactions, :created_at
  end
end

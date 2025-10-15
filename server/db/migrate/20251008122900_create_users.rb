class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: true
      t.string :display_name
      t.boolean :two_factor_enabled, default: false, null: false
      t.timestamps
    end
  end
end

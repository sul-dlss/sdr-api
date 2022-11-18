class AddCollectionsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :active, :boolean, default: true
    add_column :users, :full_access, :boolean, default: true
    add_column :users, :collections, :jsonb, default: []
    User.connection.execute("UPDATE users SET collections = '[]', active = true, full_access = true")
  end
end

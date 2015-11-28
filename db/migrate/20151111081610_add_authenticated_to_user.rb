class AddAuthenticatedToUser < ActiveRecord::Migration
  def change
    add_column :users, :authenticated, :boolean
  end
end

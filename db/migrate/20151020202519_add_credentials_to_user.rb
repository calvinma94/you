class AddCredentialsToUser < ActiveRecord::Migration
  def change
    add_column :users, :sfu_computingid, :string
    add_column :users, :sfu_password, :string
  end
end

class AddCredentialsToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :credentials, :text
  end
end

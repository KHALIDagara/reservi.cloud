class AddProviderExternalIdToChannels < ActiveRecord::Migration[8.0]
  def up
    add_column :channels, :provider_external_id, :string

    execute <<~SQL.squish
      UPDATE channels
      SET provider_external_id = CASE provider_type
        WHEN 'whatsapp' THEN provider_config ->> 'phone_number_id'
        WHEN 'instagram' THEN provider_config ->> 'instagram_id'
      END
      WHERE provider_type IN ('whatsapp', 'instagram')
    SQL

    add_index :channels, [ :provider_type, :provider_external_id ],
      unique: true,
      where: "provider_external_id IS NOT NULL",
      name: "index_channels_on_unique_provider_identity"
  end

  def down
    remove_index :channels, name: "index_channels_on_unique_provider_identity"
    remove_column :channels, :provider_external_id
  end
end

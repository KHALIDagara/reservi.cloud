class CreateTeams < ActiveRecord::Migration[8.1]
  def up
    create_table :teams do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :teams, [ :account_id, :name ], unique: true
    add_index :teams, [ :account_id, :id ], unique: true, name: "index_teams_on_account_id_and_id"
  end

  def down
    drop_table :teams
  end
end

class CreateTrackUses < ActiveRecord::Migration
  def change
    create_table :track_uses do |t|
      t.string :message
      t.integer :user

      t.timestamps
    end
  end
end

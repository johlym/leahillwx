class CreateAlmanacPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :almanac_positions do |t|
      t.date :date, null: false
      t.integer :hour, null: false

      # Sun positions
      t.float :sun_azimuth_deg
      t.float :sun_altitude_deg
      t.float :sun_ra_deg
      t.float :sun_dec_deg

      # Moon positions
      t.float :moon_azimuth_deg
      t.float :moon_altitude_deg
      t.float :moon_ra_deg
      t.float :moon_dec_deg

      t.timestamps
    end

    add_index :almanac_positions, [ :date, :hour ], unique: true
  end
end

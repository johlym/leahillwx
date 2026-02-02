class AddDetailedPositionsToAlmanacEntries < ActiveRecord::Migration[8.1]
  def change
    # Drop unused hourly positions table
    drop_table :almanac_positions, if_exists: true

    # Add 5-minute interval position data (288 samples per day)
    # Stored as array of hashes: [{m: minute, alt: altitude, az: azimuth}, ...]
    add_column :almanac_entries, :moon_positions_5min, :jsonb
    add_column :almanac_entries, :sun_positions_5min, :jsonb

    # Add distance from Earth in kilometers (at noon local time)
    add_column :almanac_entries, :moon_distance_km, :float
    add_column :almanac_entries, :sun_distance_km, :float
  end
end

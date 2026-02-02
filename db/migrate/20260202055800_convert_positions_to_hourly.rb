class ConvertPositionsToHourly < ActiveRecord::Migration[8.1]
  def change
    # Rename columns to reflect hourly data (24 samples vs 1440)
    rename_column :almanac_entries, :sun_positions_1min, :sun_positions_hourly
    rename_column :almanac_entries, :moon_positions_1min, :moon_positions_hourly

    # Note: Existing data will need to be regenerated
    # The data format changes from {m: minute, ...} to {h: hour, ...}
    # Run: rake almanac:generate_all mode=full
  end
end

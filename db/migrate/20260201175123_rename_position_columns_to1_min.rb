class RenamePositionColumnsTo1Min < ActiveRecord::Migration[8.1]
  def change
    rename_column :almanac_entries, :sun_positions_5min, :sun_positions_1min
    rename_column :almanac_entries, :moon_positions_5min, :moon_positions_1min
  end
end

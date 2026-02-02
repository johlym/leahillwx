class AddTwilightTimesToAlmanacEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :almanac_entries, :astronomical_dawn_at, :datetime
    add_column :almanac_entries, :astronomical_dusk_at, :datetime
    add_column :almanac_entries, :nautical_dawn_at, :datetime
    add_column :almanac_entries, :nautical_dusk_at, :datetime
  end
end

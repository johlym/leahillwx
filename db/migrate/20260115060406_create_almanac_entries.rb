class CreateAlmanacEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :almanac_entries do |t|
      t.date :date, null: false, index: { unique: true }
      t.string :timezone, null: false, default: "America/Los_Angeles"

      # Sun events
      t.datetime :sunrise_at
      t.datetime :sunset_at
      t.datetime :civil_dawn_at
      t.datetime :civil_dusk_at
      t.datetime :solar_noon_at

      # Daylight calculations
      t.integer :daylight_seconds
      t.integer :daylight_delta_seconds

      # Moon events
      t.datetime :moonrise_at
      t.datetime :moonset_at
      t.datetime :moon_transit_at

      # Moon phase
      t.string :moon_phase
      t.float :moon_illumination_pct

      # Astronomical events (next occurrences)
      t.datetime :next_new_moon_at
      t.datetime :next_full_moon_at
      t.datetime :next_equinox_at
      t.datetime :next_solstice_at

      t.timestamps
    end
  end
end

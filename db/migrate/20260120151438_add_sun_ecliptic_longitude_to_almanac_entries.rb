class AddSunEclipticLongitudeToAlmanacEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :almanac_entries, :sun_ecliptic_longitude_deg, :float
  end
end

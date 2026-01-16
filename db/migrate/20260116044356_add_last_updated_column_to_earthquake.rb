class AddLastUpdatedColumnToEarthquake < ActiveRecord::Migration[8.1]
  def change
    add_column :earthquakes, :last_updated, :datetime
  end
end

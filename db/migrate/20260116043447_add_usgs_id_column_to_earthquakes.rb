class AddUsgsIdColumnToEarthquakes < ActiveRecord::Migration[8.1]
  def change
    add_column :earthquakes, :usgs_id, :string
  end
end

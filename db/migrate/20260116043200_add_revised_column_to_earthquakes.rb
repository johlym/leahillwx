class AddRevisedColumnToEarthquakes < ActiveRecord::Migration[8.1]
  def change
    add_column :earthquakes, :revised, :boolean, default: false
  end
end

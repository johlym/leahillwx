class CreateEarthquakes < ActiveRecord::Migration[8.1]
  def change
    create_table :earthquakes do |t|
      t.float :magnitude
      t.string :place
      t.datetime :eventtime
      t.string :url
      t.float :lat
      t.float :lon
      t.float :depth
      t.float :distance
      t.timestamps
    end
  end
end

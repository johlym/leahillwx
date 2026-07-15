class AddForecastAndEarthquakeIndexes < ActiveRecord::Migration[8.1]
  def up
    add_index :forecasts, [ :interval, :created_at ], order: { created_at: :desc }, name: "index_forecasts_on_interval_and_created_at"

    execute <<~SQL
      DELETE FROM earthquakes
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY usgs_id
                   ORDER BY id ASC
                 ) AS row_num
          FROM earthquakes
          WHERE usgs_id IS NOT NULL
        ) ranked
        WHERE ranked.row_num > 1
      )
    SQL

    add_index :earthquakes, :usgs_id, unique: true
    add_index :earthquakes, :eventtime
  end

  def down
    remove_index :earthquakes, :eventtime
    remove_index :earthquakes, :usgs_id
    remove_index :forecasts, name: "index_forecasts_on_interval_and_created_at"
  end
end

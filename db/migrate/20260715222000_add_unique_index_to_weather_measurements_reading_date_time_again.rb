class AddUniqueIndexToWeatherMeasurementsReadingDateTimeAgain < ActiveRecord::Migration[8.1]
  def up
    # Keep the earliest row for each duplicate timestamp, then enforce uniqueness.
    execute <<~SQL
      DELETE FROM weather_measurements
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY reading_date_time
                   ORDER BY id ASC
                 ) AS row_num
          FROM weather_measurements
        ) ranked
        WHERE ranked.row_num > 1
      )
    SQL

    remove_index :weather_measurements, :reading_date_time
    add_index :weather_measurements, :reading_date_time, unique: true
  end

  def down
    remove_index :weather_measurements, :reading_date_time
    add_index :weather_measurements, :reading_date_time
  end
end

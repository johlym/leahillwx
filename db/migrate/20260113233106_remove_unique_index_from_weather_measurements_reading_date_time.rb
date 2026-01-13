class RemoveUniqueIndexFromWeatherMeasurementsReadingDateTime < ActiveRecord::Migration[8.1]
  def change
    remove_index :weather_measurements, :reading_date_time
    add_index :weather_measurements, :reading_date_time
  end
end

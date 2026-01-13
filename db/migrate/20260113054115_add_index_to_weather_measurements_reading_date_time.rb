class AddIndexToWeatherMeasurementsReadingDateTime < ActiveRecord::Migration[8.1]
  def change
    add_index :weather_measurements, :reading_date_time
  end
end

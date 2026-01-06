class DropColumnsToBeDerivedFromWeatherMeasurement < ActiveRecord::Migration[8.1]
  def change
    remove_column :weather_measurements, :day_max_wind
    remove_column :weather_measurements, :rain_day
    remove_column :weather_measurements, :rain_event
  end
end

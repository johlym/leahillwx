class AddRainDayColumnToWeatherMeasurement < ActiveRecord::Migration[8.1]
  def change
    add_column :weather_measurements, :rain_day, :float, default: 0.0
  end
end

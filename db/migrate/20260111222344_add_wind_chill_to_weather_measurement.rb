class AddWindChillToWeatherMeasurement < ActiveRecord::Migration[8.1]
  def change
    add_column :weather_measurements, :wind_chill, :float, default: 0.0
  end
end

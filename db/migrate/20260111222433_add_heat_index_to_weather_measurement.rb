class AddHeatIndexToWeatherMeasurement < ActiveRecord::Migration[8.1]
  def change
    add_column :weather_measurements, :heat_index, :float, default: 0.0
  end
end

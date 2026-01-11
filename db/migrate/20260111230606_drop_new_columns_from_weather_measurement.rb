class DropNewColumnsFromWeatherMeasurement < ActiveRecord::Migration[8.1]
  def change
    remove_column :weather_measurements, :dew_point
    remove_column :weather_measurements, :heat_index
    remove_column :weather_measurements, :wind_chill
  end
end

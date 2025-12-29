class ChangeWeatherMeasurementColumnsToIntegers < ActiveRecord::Migration[8.1]
  def change
    change_column :weather_measurements, :humidity, :integer
    change_column :weather_measurements, :uv, :integer
    change_column :weather_measurements, :wind_dir, :integer
  end
end

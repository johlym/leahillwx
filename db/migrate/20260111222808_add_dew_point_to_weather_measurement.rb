class AddDewPointToWeatherMeasurement < ActiveRecord::Migration[8.1]
  def change
    add_column :weather_measurements, :dew_point, :float, default: 0.0
  end
end

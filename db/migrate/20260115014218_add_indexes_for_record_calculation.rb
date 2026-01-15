class AddIndexesForRecordCalculation < ActiveRecord::Migration[8.1]
  def change
    add_index :weather_measurements, :temperature
    add_index :weather_measurements, :humidity
    add_index :weather_measurements, :gust_speed
    add_index :weather_measurements, :barometer_rel
    add_index :weather_measurements, :light
    add_index :weather_measurements, :wind_speed
    add_index :weather_measurements, :rain_day
    add_index :weather_measurements, :rain_rate
  end
end

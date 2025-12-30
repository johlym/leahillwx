class WeatherMeasurementsNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :weather_measurements, :reading_date_time, false
    change_column_null :weather_measurements, :barometer_abs, false
    change_column_null :weather_measurements, :barometer_rel, false
    change_column_null :weather_measurements, :day_max_wind, false
    change_column_null :weather_measurements, :gust_speed, false
    change_column_null :weather_measurements, :light, false
    change_column_null :weather_measurements, :humidity, false
    change_column_null :weather_measurements, :temperature, false
    change_column_null :weather_measurements, :rain_day, false
    change_column_null :weather_measurements, :rain_event, false
    change_column_null :weather_measurements, :rain_rate, false
    change_column_null :weather_measurements, :uv, false
    change_column_null :weather_measurements, :uvi, false
    change_column_null :weather_measurements, :wind_dir, false
    change_column_null :weather_measurements, :wind_speed, false
  end
end

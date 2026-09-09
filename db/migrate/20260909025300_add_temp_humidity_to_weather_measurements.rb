# frozen_string_literal: true

class AddTempHumidityToWeatherMeasurements < ActiveRecord::Migration[8.1]
  def change
    # Up to 8 wireless temp/humidity sensors:
    # [{channel:, temperature:, humidity:, battery_low:}, ...]
    add_column :weather_measurements, :temp_humidity, :jsonb, null: false, default: []
  end
end

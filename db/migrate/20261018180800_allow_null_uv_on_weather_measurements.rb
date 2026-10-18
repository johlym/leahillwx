# frozen_string_literal: true

class AllowNullUvOnWeatherMeasurements < ActiveRecord::Migration[8.1]
  def change
    # Register 0x16 (UV radiation, µW/m²) is no longer always present.
    # NULL means "not sent". Do not backfill with 0.
    change_column_null :weather_measurements, :uv, true
  end
end

class AddSoilToWeatherMeasurements < ActiveRecord::Migration[8.1]
  def change
    # Up to 8 soil moisture sensors: [{channel:, moisture:, battery:}, ...]
    add_column :weather_measurements, :soil, :jsonb, null: false, default: []
  end
end

class AddTempProbesToWeatherMeasurements < ActiveRecord::Migration[8.1]
  def change
    # Up to 8 soil temperature probes: [{channel:, temperature:, battery:}, ...]
    add_column :weather_measurements, :temp_probes, :jsonb, null: false, default: []
  end
end

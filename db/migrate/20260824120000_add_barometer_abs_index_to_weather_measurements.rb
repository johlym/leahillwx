class AddBarometerAbsIndexToWeatherMeasurements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :weather_measurements, :barometer_abs, algorithm: :concurrently
  end
end

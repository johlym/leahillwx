class CreateRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :records do |t|
      t.string :scope, null: false
      t.integer :year

      t.float :highest_temp
      t.datetime :highest_temp_at
      t.float :lowest_temp
      t.datetime :lowest_temp_at
      t.float :highest_apparent_temp
      t.datetime :highest_apparent_temp_at
      t.float :lowest_apparent_temp
      t.datetime :lowest_apparent_temp_at
      t.float :highest_heat_index
      t.datetime :highest_heat_index_at
      t.float :lowest_wind_chill
      t.datetime :lowest_wind_chill_at
      t.float :largest_temp_range
      t.date :largest_temp_range_date
      t.float :smallest_temp_range
      t.date :smallest_temp_range_date

      t.float :strongest_gust
      t.datetime :strongest_gust_at
      t.float :highest_wind_run
      t.date :highest_wind_run_date
      t.integer :longest_calm_hours
      t.datetime :longest_calm_start_at

      t.float :highest_daily_rain
      t.date :highest_daily_rain_date
      t.float :highest_rain_rate
      t.datetime :highest_rain_rate_at
      t.integer :wettest_month
      t.integer :wettest_month_year
      t.float :wettest_month_total
      t.integer :consecutive_rain_days
      t.date :consecutive_rain_start_date
      t.integer :consecutive_dry_days
      t.date :consecutive_dry_start_date

      t.integer :highest_humidity
      t.datetime :highest_humidity_at
      t.integer :lowest_humidity
      t.datetime :lowest_humidity_at
      t.float :highest_dew_point
      t.datetime :highest_dew_point_at
      t.float :lowest_dew_point
      t.datetime :lowest_dew_point_at

      t.float :highest_pressure
      t.datetime :highest_pressure_at
      t.float :lowest_pressure
      t.datetime :lowest_pressure_at
      t.float :largest_pressure_swing
      t.date :largest_pressure_swing_date

      t.float :highest_solar
      t.datetime :highest_solar_at

      t.timestamps

      t.index [ :scope, :year ], unique: true
    end
  end
end

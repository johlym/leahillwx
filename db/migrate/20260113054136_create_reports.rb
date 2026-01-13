class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.float :month_mean_temp
      t.float :month_high_temp
      t.integer :month_high_temp_day
      t.float :month_low_temp
      t.integer :month_low_temp_day
      t.float :total_heat_degree_days
      t.float :total_cool_degree_days
      t.float :total_rain
      t.float :avg_wind_speed
      t.float :month_high_wind_speed
      t.integer :month_high_wind_day
      t.integer :dominant_wind_dir
      t.string :dominant_wind_dir_compass

      t.timestamps
    end

    add_index :reports, [ :year, :month ], unique: true
  end
end

class CreateReportEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :report_entries do |t|
      t.references :report, null: false, foreign_key: { on_delete: :cascade }
      t.integer :day, null: false
      t.float :mean_temp
      t.float :high_temp
      t.string :high_temp_time
      t.float :low_temp
      t.string :low_temp_time
      t.float :heat_degree_days
      t.float :cool_degree_days
      t.float :rain
      t.float :avg_wind_speed
      t.float :high_wind_speed
      t.string :high_wind_time
      t.integer :wind_dir
      t.string :wind_dir_compass
      t.boolean :partial_day, default: false, null: false

      t.timestamps
    end

    add_index :report_entries, [ :report_id, :day ], unique: true
  end
end

class AddPressureToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :report_entries, :mean_pressure, :float
    add_column :report_entries, :high_pressure, :float
    add_column :report_entries, :high_pressure_time, :string
    add_column :report_entries, :low_pressure, :float
    add_column :report_entries, :low_pressure_time, :string

    add_column :reports, :month_mean_pressure, :float
    add_column :reports, :month_high_pressure, :float
    add_column :reports, :month_high_pressure_day, :integer
    add_column :reports, :month_low_pressure, :float
    add_column :reports, :month_low_pressure_day, :integer
  end
end

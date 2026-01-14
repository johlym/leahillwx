class AddHourAndRenamePartialDayInReportEntries < ActiveRecord::Migration[8.1]
  def change
    # Add hour column (nullable - nil for daily entries, 0-23 for hourly)
    add_column :report_entries, :hour, :integer

    # Rename partial_day to partial_period (more generic)
    rename_column :report_entries, :partial_day, :partial_period

    # Remove old uniqueness constraint
    remove_index :report_entries, name: "index_report_entries_on_report_id_and_day"

    # Add new uniqueness constraint including hour
    add_index :report_entries, [ :report_id, :day, :hour ], unique: true, name: "index_report_entries_on_report_day_hour"
  end
end

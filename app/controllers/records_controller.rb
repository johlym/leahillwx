class RecordsController < ApplicationController
  def index
    @available_years = Record.where(scope: "yearly").order(year: :desc).pluck(:year)

    @all_time_record = Record.all_time_record

    if params[:year].present?
      @selected_year = params[:year].to_i
      @selected_year_record = Record.for_year(@selected_year).first
      @pivot = :year
    else
      @selected_year = nil
      @selected_year_record = nil
      @pivot = :all_time
    end

    # For the heatmap, use the pivoted year when set, otherwise the
    # most recent year that has any daily entries. Falls back to nil if
    # nothing is available and the component will render an empty state.
    heatmap_year = @selected_year || most_recent_year_with_data
    @heatmap_year = heatmap_year
    @heatmap_days = heatmap_year ? load_heatmap_days(heatmap_year) : []
  end

  private

  def most_recent_year_with_data
    Report.where.not(id: nil).maximum(:year)
  end

  def load_heatmap_days(year)
    ReportEntry
      .joins(:report)
      .where(hour: nil)
      .where(reports: { year: year })
      .where.not(mean_temp: nil)
      .order("reports.month, day")
      .pluck(Arel.sql("reports.month"), :day, :high_temp, :low_temp, :mean_temp, :partial_period)
      .map { |month, day, hi_c, lo_c, mean_c, partial|
        {
          month: month,
          day: day,
          high_f: hi_c ? (hi_c * 9.0 / 5.0 + 32.0) : nil,
          low_f: lo_c ? (lo_c * 9.0 / 5.0 + 32.0) : nil,
          mean_f: mean_c ? (mean_c * 9.0 / 5.0 + 32.0) : nil,
          partial: !!partial
        }
      }
  end
end

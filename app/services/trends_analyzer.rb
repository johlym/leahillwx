# frozen_string_literal: true

# Computes the shape of the Trends page from Report + ReportEntry data.
# Everything is pre-aggregated by the reports pipeline, so this stays
# a light aggregator over the monthly/daily rows.
class TrendsAnalyzer
  # Number of most recent complete years used as the "normal" baseline.
  NORMAL_YEARS = 5

  # Rolling-window sizes on daily data.
  ROLLING_WINDOWS = [ 30, 90, 365 ].freeze

  def initialize(year: nil)
    @focus_year = year || Report.maximum(:year) || Date.current.year
  end

  attr_reader :focus_year

  # Years for which we have any Report row, newest first.
  def available_years
    @available_years ||= Report.distinct.order(year: :desc).pluck(:year)
  end

  # ---- Year-over-year monthly series -------------------------------
  # Returns { years: [...], months: [...], datasets: [{ year, temps, rain, wind_peak, wind_avg }] }
  def yoy_series
    years = available_years.first(6).sort
    months = (1..12).to_a
    reports = Report.where(year: years).order(:year, :month)
    grouped = reports.group_by(&:year)

    datasets = years.map do |y|
      by_month = grouped[y]&.index_by(&:month) || {}
      {
        year: y,
        temps: months.map { |m| c_to_f(by_month[m]&.month_mean_temp) },
        rain: months.map { |m| mm_to_in(by_month[m]&.total_rain) },
        wind_peak: months.map { |m| mps_to_mph(by_month[m]&.month_high_wind_speed) },
        wind_avg: months.map { |m| mps_to_mph(by_month[m]&.avg_wind_speed) }
      }
    end

    { years: years, months: months, datasets: datasets }
  end

  # ---- Rolling-window daily series --------------------------------
  # Returns { labels: [dates], temp_series: [avg30, avg90, avg365], rain_cumulative }
  def rolling_series
    daily = ReportEntry
      .joins(:report)
      .where(hour: nil)
      .order("reports.year, reports.month, day")
      .pluck(Arel.sql("reports.year"), Arel.sql("reports.month"), :day, :mean_temp, :rain)

    dated = daily.filter_map do |year, month, day, mean_c, rain_mm|
      next unless Date.valid_date?(year, month, day)
      {
        date: Date.new(year, month, day),
        mean_f: mean_c ? c_to_f(mean_c) : nil,
        rain_in: rain_mm ? mm_to_in(rain_mm) : 0.0
      }
    end

    labels = dated.map { |d| d[:date].to_s }
    temps = dated.map { |d| d[:mean_f] }

    temp_series = ROLLING_WINDOWS.map do |w|
      {
        label: "#{w}-day mean temp",
        window: w,
        data: rolling_average(temps, w).map { |v| v&.round(2) }
      }
    end

    # Cumulative rainfall for the focus year.
    year_daily = dated.select { |d| d[:date].year == focus_year }
    rain_cumulative = {
      labels: year_daily.map { |d| d[:date].strftime("%b %-d") },
      data: cumulative(year_daily.map { |d| d[:rain_in] || 0.0 }).map { |v| v.round(2) }
    }

    { labels: labels, temps: temp_series, rain_cumulative: rain_cumulative }
  end

  # ---- Anomaly summary cards --------------------------------------
  # Returns array of { label, value, unit, secondary, trend, trend_label }
  def anomalies
    normal_years = complete_normal_years
    return [] if normal_years.empty?

    focus_reports = Report.where(year: focus_year).order(:month)
    return [] if focus_reports.empty?

    baseline = Report.where(year: normal_years).group(:month).average(:month_mean_temp)
    baseline_rain = Report.where(year: normal_years).group(:month).average(:total_rain)
    baseline_wind = Report.where(year: normal_years).group(:month).average(:avg_wind_speed)

    ytd_focus_mean = focus_reports.average(:month_mean_temp)
    ytd_focus_rain_mm = focus_reports.sum(:total_rain)
    ytd_focus_wind_mps = focus_reports.average(:avg_wind_speed)

    months_in_focus = focus_reports.pluck(:month).uniq
    baseline_mean = baseline.values_at(*months_in_focus).compact
    baseline_rain_total_mm = baseline_rain.values_at(*months_in_focus).compact.sum
    baseline_wind_mean = baseline_wind.values_at(*months_in_focus).compact

    baseline_mean_avg = baseline_mean.any? ? baseline_mean.sum / baseline_mean.length : nil
    baseline_wind_avg = baseline_wind_mean.any? ? baseline_wind_mean.sum / baseline_wind_mean.length : nil

    cards = []

    if ytd_focus_mean && baseline_mean_avg
      delta_f = c_to_f(ytd_focus_mean) - c_to_f(baseline_mean_avg)
      cards << anomaly_card(
        label: "vs #{normal_years.length}-year normal",
        title: "Temperature",
        value: format_delta(delta_f, "°"),
        secondary: "focus #{c_to_f(ytd_focus_mean).round(1)}° · normal #{c_to_f(baseline_mean_avg).round(1)}°",
        delta: delta_f,
        positive_label: "warmer",
        negative_label: "cooler"
      )
    end

    if ytd_focus_rain_mm && baseline_rain_total_mm > 0
      focus_in = mm_to_in(ytd_focus_rain_mm)
      normal_in = mm_to_in(baseline_rain_total_mm)
      delta_in = focus_in - normal_in
      cards << anomaly_card(
        label: "vs #{normal_years.length}-year normal",
        title: "Rainfall",
        value: format_delta(delta_in, " in"),
        secondary: "focus #{focus_in.round(2)} in · normal #{normal_in.round(2)} in",
        delta: delta_in,
        positive_label: "wetter",
        negative_label: "drier"
      )
    end

    if ytd_focus_wind_mps && baseline_wind_avg
      focus_mph = mps_to_mph(ytd_focus_wind_mps)
      normal_mph = mps_to_mph(baseline_wind_avg)
      delta_mph = focus_mph - normal_mph
      cards << anomaly_card(
        label: "vs #{normal_years.length}-year normal",
        title: "Wind",
        value: format_delta(delta_mph, " mph"),
        secondary: "focus #{focus_mph.round(1)} mph · normal #{normal_mph.round(1)} mph",
        delta: delta_mph,
        positive_label: "windier",
        negative_label: "calmer"
      )
    end

    cards
  end

  private

  def complete_normal_years
    current = Date.current.year
    (available_years - [ current, focus_year ]).first(NORMAL_YEARS)
  end

  def anomaly_card(title:, label:, value:, secondary:, delta:, positive_label:, negative_label:)
    trend = if delta.abs < 0.05
      :flat
    else
      delta.positive? ? :up : :down
    end
    trend_label = case trend
                  when :flat then "unchanged"
                  when :up then positive_label
                  when :down then negative_label
                  end
    {
      title: title,
      label: label,
      value: value,
      secondary: secondary,
      trend: trend,
      trend_label: trend_label
    }
  end

  def format_delta(value, unit)
    sign = value >= 0 ? "+" : ""
    "#{sign}#{value.round(2)}#{unit}"
  end

  def rolling_average(series, window)
    return [] if series.empty?
    result = Array.new(series.length)
    series.each_with_index do |_, i|
      slice = series[[ i - window + 1, 0 ].max..i].compact
      result[i] = slice.any? ? (slice.sum.to_f / slice.length) : nil
    end
    result
  end

  def cumulative(series)
    total = 0.0
    series.map { |v| total += v || 0.0; total }
  end

  def c_to_f(celsius)
    return nil unless celsius
    celsius * 9.0 / 5.0 + 32
  end

  def mm_to_in(mm)
    return nil unless mm
    mm / 25.4
  end

  def mps_to_mph(mps)
    return nil unless mps
    mps * 2.23694
  end
end

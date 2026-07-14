class TrendsController < ApplicationController
  def index
    load_trends(params[:year]&.to_i)
    render :index
  end

  def show
    load_trends(params[:year].to_i)
    render :index
  end

  private

  def load_trends(year)
    @analyzer = TrendsAnalyzer.new(year: year)
    @focus_year = @analyzer.focus_year
    @available_years = @analyzer.available_years

    yoy = @analyzer.yoy_series
    rolling = @analyzer.rolling_series

    @yoy_temp_chart = yoy_chart(yoy, :temps, "°F", "Temperature (°F)", 1)
    @yoy_rain_chart = yoy_chart(yoy, :rain, " in", "Rainfall (in)", 2)
    @yoy_wind_chart = yoy_chart(yoy, :wind_peak, " mph", "Peak wind (mph)", 1)

    @rolling_temp_chart = rolling_temp_chart(rolling)
    @rain_cumulative_chart = cumulative_rain_chart(rolling[:rain_cumulative])
    @aqi_daily_chart = aqi_daily_chart(@focus_year)

    @anomalies = @analyzer.anomalies
    @has_data = @available_years.any?
  end

  def aqi_daily_chart(year)
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    from = zone.local(year, 1, 1).beginning_of_day
    to = zone.local(year, 12, 31).end_of_day
    series = Aqi.daily_averages(from: from, to: to)
    return nil if series.blank?

    {
      type: "line",
      data: {
        labels: series.map { |row| row[:date].strftime("%b %-d") },
        datasets: [
          {
            label: "Daily avg AQI",
            data: series.map { |row| row[:epa_aqi] },
            borderWidth: 2,
            tension: 0.2,
            pointRadius: 0,
            color: "rgb(255, 126, 0)",
            yAxisID: "y"
          },
          {
            label: "Daily avg PM2.5",
            data: series.map { |row| row[:pm2_5] },
            borderWidth: 2,
            tension: 0.2,
            pointRadius: 0,
            color: "rgb(143, 63, 151)",
            yAxisID: "y2",
            dashed: true
          }
        ]
      },
      options: {
        yUnit: "",
        yLabel: "AQI",
        y2Unit: " µg/m³",
        y2Label: "PM2.5 (µg/m³)",
        decimals: 1,
        beginAtZero: true
      }
    }
  end

  def yoy_chart(yoy, series_key, unit, y_label, decimals)
    labels = yoy[:months].map { |m| Date::ABBR_MONTHNAMES[m] }
    focus_year = @focus_year

    {
      type: "line",
      data: {
        labels: labels,
        datasets: yoy[:datasets].map do |ds|
          is_focus = ds[:year] == focus_year
          {
            label: ds[:year].to_s,
            data: ds[series_key].map { |v| v&.round(decimals) },
            borderWidth: is_focus ? 3 : 1.5,
            pointRadius: is_focus ? 3 : 0,
            tension: 0.25,
            dashed: !is_focus && ds[:year] < focus_year
          }
        end
      },
      options: {
        yUnit: unit,
        yLabel: y_label,
        decimals: decimals
      }
    }
  end

  def rolling_temp_chart(rolling)
    {
      type: "line",
      data: {
        labels: rolling[:labels],
        datasets: rolling[:temps].map.with_index do |series, i|
          {
            label: series[:label],
            data: series[:data],
            borderWidth: 2,
            tension: 0.3,
            dashed: series[:window] == 30
          }
        end
      },
      options: {
        yUnit: "°F",
        yLabel: "Rolling mean (°F)",
        decimals: 1
      }
    }
  end

  def cumulative_rain_chart(cumulative)
    return nil if cumulative[:labels].blank?

    {
      type: "line",
      data: {
        labels: cumulative[:labels],
        datasets: [
          {
            label: "Cumulative rain",
            data: cumulative[:data],
            borderWidth: 2,
            tension: 0.15,
            fill: true,
            color: "var(--chart-6)"
          }
        ]
      },
      options: {
        yUnit: " in",
        yLabel: "Rain year-to-date (in)",
        decimals: 2,
        hideLegend: true
      }
    }
  end
end

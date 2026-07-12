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

    @anomalies = @analyzer.anomalies
    @has_data = @available_years.any?
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

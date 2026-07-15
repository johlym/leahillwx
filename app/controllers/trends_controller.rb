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

    charts = Trends::Charts.new(analyzer: @analyzer)
    @yoy_temp_chart = charts.yoy_temp_chart
    @yoy_rain_chart = charts.yoy_rain_chart
    @yoy_wind_chart = charts.yoy_wind_chart
    @rolling_temp_chart = charts.rolling_temp_chart
    @rain_cumulative_chart = charts.rain_cumulative_chart
    @aqi_daily_chart = charts.aqi_daily_chart

    @anomalies = @analyzer.anomalies
    @has_data = @available_years.any?
  end
end

require "test_helper"
require "sidekiq/testing"

class RootControllerTest < ActionDispatch::IntegrationTest
  setup do
    Sidekiq::Testing.fake!
    DownloadOpenWeatherForecastJob.clear
    DownloadAirNowAqiJob.clear
  end

  teardown do
    DownloadOpenWeatherForecastJob.clear
    DownloadAirNowAqiJob.clear
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "layout exposes language, skip link, and mobile menu controls" do
    get root_url
    assert_response :success
    assert_select "html[lang=en]"
    assert_select "a.skip-link[href='#main-content']", text: "Skip to content"
    assert_select "main#main-content"
    assert_select "button#mobile-menu-toggle[aria-controls=mobile-menu]"
    assert_select "#mobile-menu[role=navigation][aria-labelledby=mobile-menu-toggle]"
    assert_select "[data-connection-status-target=badge] [data-connection-status-target=label]", text: "OFFLINE"
    assert_select "meta[name=sentry-trace]", count: 0
    assert_select "meta[name=baggage]", count: 0
  end

  test "index defers weather alerts to async turbo frame" do
    get root_url
    assert_response :success
    assert_select "header.site-header turbo-frame#weather_alerts_bar[src='#{alerts_bar_path}']"
    assert_select "header.site-header a.forecast-alerts-bar", count: 0
  end

  test "index enqueues forecast download when no forecast exists" do
    Forecast.delete_all

    get root_url

    assert_response :success
    assert_equal 1, DownloadOpenWeatherForecastJob.jobs.size
  end

  test "index enqueues forecast download when forecast is stale" do
    Forecast.delete_all
    Forecast.create!(forecast: { daily: [] }, created_at: 2.hours.ago, updated_at: 2.hours.ago)

    get root_url

    assert_response :success
    assert_equal 1, DownloadOpenWeatherForecastJob.jobs.size
  end

  test "index does not enqueue forecast download when forecast is fresh" do
    Forecast.delete_all
    Forecast.create!(forecast: { daily: [] }, created_at: 10.minutes.ago, updated_at: 10.minutes.ago)
    DownloadOpenWeatherForecastJob.clear

    get root_url

    assert_response :success
    assert_equal 0, DownloadOpenWeatherForecastJob.jobs.size
  end

  test "index enqueues AirNow AQI download when latest reading is openweather" do
    Aqi.delete_all
    Aqi.upsert_reading!(
      observed_at: 1.hour.ago,
      pm2_5: 12.0,
      source: "openweather"
    )
    DownloadAirNowAqiJob.clear

    get root_url

    assert_response :success
    assert_equal 1, DownloadAirNowAqiJob.jobs.size
  end

  test "index does not enqueue AirNow AQI download when airnow reading is fresh" do
    Aqi.delete_all
    Aqi.upsert_reading!(
      observed_at: 1.hour.ago,
      pm2_5: 3.8,
      epa_aqi: 18,
      source: "airnow"
    )
    DownloadAirNowAqiJob.clear

    get root_url

    assert_response :success
    assert_equal 0, DownloadAirNowAqiJob.jobs.size
  end

  test "index renders offline empty state when weather_measurements is empty" do
    WeatherMeasurement.delete_all

    get root_url

    assert_response :success
    assert_select "section.current-conditions[aria-label='Station offline']"
    assert_select "h1", text: "Station offline"
    assert_select ".status-badge", text: /Awaiting first reading/
  end

  test "about renders when weather_measurements is empty" do
    WeatherMeasurement.delete_all

    get about_url

    assert_response :success
    assert_match(/First measurement:\s*None yet/, response.body)
  end
end

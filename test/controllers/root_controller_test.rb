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
    assert_select "header.site-header"
    assert_select "section.sky-hazards", count: 1
    assert_select ".tv-stage", count: 0
  end

  test "tv display cycles five full-screen slides without site chrome" do
    get root_url(tv: "true")

    assert_response :success
    assert_select "html.tv-display-root"
    assert_select "body.tv-display"
    assert_select "title", text: "Display — Lea Hill Weather"
    assert_select "meta[name=theme-color][content='#000000']"
    assert_select "header.site-header", count: 0
    assert_select "footer.site-footer", count: 0
    assert_select "a.skip-link[href='#main-content']"
    assert_select "main#main-content"
    assert_select "h1", text: "Lea Hill Weather display"
    assert_select ".tv-stage[data-controller=tv-cycle][data-tv-cycle-interval-value='10000'][aria-roledescription=carousel]"
    assert_select ".tv-slide", count: 5
    assert_select ".tv-slide.is-active", count: 1
    assert_select ".tv-slide--conditions.is-active[aria-label='1 of 5: Current conditions']"
    assert_select ".tv-slide--conditions section.sky-hazards", count: 0
    assert_select ".tv-slide--conditions .current-hero-temp"
    assert_select ".tv-slide--sky[inert][aria-hidden=true][aria-label='2 of 5: Sky and nearby hazards'] section.sky-hazards", count: 1
    assert_select ".tv-slide--forecast[inert][aria-label='3 of 5: 7-day forecast'] .weekly-forecast"
    assert_select ".tv-slide--forecast .forecast-temps .high", text: /High \d+°/
    assert_select ".tv-slide--cameras", count: 2
    assert_select ".tv-slide--cameras[aria-label='4 of 5: Traffic cameras'] #traffic_cameras"
    assert_select ".tv-slide--cameras[aria-label='4 of 5: Traffic cameras'] #airport_cameras", count: 0
    assert_select ".tv-slide--cameras[aria-label='5 of 5: Airport cameras'] #airport_cameras"
    assert_select ".tv-slide--cameras[aria-label='5 of 5: Airport cameras'] #traffic_cameras", count: 0
    assert_select ".hourly-forecast", count: 0
    assert_select "table.earthquake-table", count: 0
    assert_select "button.tv-progress[type=button][aria-pressed=false][aria-label='Pause display rotation']"
    assert_select "svg.tv-progress-svg[aria-hidden=true]"
    assert_select ".tv-progress-count", text: "10"
    assert_select "#tv-progress-help"
    assert_select "[data-tv-cycle-target=status][aria-live=polite]"
  end

  test "tv query other than true keeps the normal homepage" do
    get root_url(tv: "1")

    assert_response :success
    assert_select "header.site-header"
    assert_select ".tv-stage", count: 0
  end

  test "tv display shows the offline state inside the first slide" do
    WeatherMeasurement.delete_all

    get root_url(tv: "true")

    assert_response :success
    assert_select "header.site-header", count: 0
    assert_select ".tv-slide", count: 5
    assert_select "h1", text: "Lea Hill Weather display"
    assert_select ".tv-slide--conditions h2", text: "Station offline"
    assert_select "h1", count: 1
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

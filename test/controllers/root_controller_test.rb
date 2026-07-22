require "test_helper"
require "sidekiq/testing"

class RootControllerTest < ActionDispatch::IntegrationTest
  setup do
    Sidekiq::Testing.fake!
    DownloadOpenWeatherForecastJob.clear
  end

  teardown do
    DownloadOpenWeatherForecastJob.clear
  end

  test "should get index" do
    stub_librewxr_alerts([]) do
      get root_url
      assert_response :success
    end
  end

  test "index renders LibreWXR weather alerts" do
    stub_librewxr_alerts([
      WeatherAlert.new(
        event: "Heat Advisory",
        description: "Hot conditions expected across the lowlands.",
        starts_at: 1.hour.ago,
        ends_at: 2.hours.from_now,
        source: "librewxr"
      )
    ]) do
      get root_url
      assert_response :success
      assert_select "a.forecast-alerts-bar[href='#{alerts_path}']", text: /Heat Advisory/
    assert_select "a.forecast-alerts-bar", text: /Until/
    assert_select "a.forecast-alerts-bar", text: /Hot conditions/, count: 0
    end
  end

  test "index enqueues forecast download when no forecast exists" do
    Forecast.delete_all

    stub_librewxr_alerts([]) do
      get root_url

      assert_response :success
      assert_equal 1, DownloadOpenWeatherForecastJob.jobs.size
    end
  end

  test "index enqueues forecast download when forecast is stale" do
    Forecast.delete_all
    Forecast.create!(forecast: { daily: [] }, created_at: 2.hours.ago, updated_at: 2.hours.ago)

    stub_librewxr_alerts([]) do
      get root_url

      assert_response :success
      assert_equal 1, DownloadOpenWeatherForecastJob.jobs.size
    end
  end

  test "index does not enqueue forecast download when forecast is fresh" do
    Forecast.delete_all
    Forecast.create!(forecast: { daily: [] }, created_at: 10.minutes.ago, updated_at: 10.minutes.ago)
    DownloadOpenWeatherForecastJob.clear

    stub_librewxr_alerts([]) do
      get root_url

      assert_response :success
      assert_equal 0, DownloadOpenWeatherForecastJob.jobs.size
    end
  end

  private

  def stub_librewxr_alerts(alerts)
    fake = Object.new
    fake.define_singleton_method(:fetch) { alerts }

    LibreWxrAlertsClient.singleton_class.alias_method(:__orig_new, :new)
    LibreWxrAlertsClient.define_singleton_method(:new) { |*_args, **_kwargs| fake }
    yield
  ensure
    LibreWxrAlertsClient.singleton_class.remove_method(:new)
    LibreWxrAlertsClient.singleton_class.alias_method(:new, :__orig_new)
    LibreWxrAlertsClient.singleton_class.remove_method(:__orig_new)
  end
end

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
    get root_url
    assert_response :success
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
end

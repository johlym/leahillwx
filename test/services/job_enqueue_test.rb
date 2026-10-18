# frozen_string_literal: true

require "test_helper"
require "sidekiq/testing"

class JobEnqueueTest < ActiveSupport::TestCase
  setup do
    Sidekiq::Testing.fake!
    DownloadOpenWeatherForecastJob.clear
    ENV["JOB_ENQUEUE_FORCE_COOLDOWN"] = "1"
    Sidekiq.redis do |conn|
      keys = conn.keys("job_enqueue:*")
      conn.del(*keys) if keys.any?
    end
  end

  teardown do
    ENV.delete("JOB_ENQUEUE_FORCE_COOLDOWN")
    DownloadOpenWeatherForecastJob.clear
    Sidekiq.redis do |conn|
      keys = conn.keys("job_enqueue:*")
      conn.del(*keys) if keys.any?
    end
  end

  test "once enqueues a job only once within the cooldown window" do
    assert JobEnqueue.once(DownloadOpenWeatherForecastJob, cooldown: 5.minutes)
    assert_equal 1, DownloadOpenWeatherForecastJob.jobs.size

    assert_not JobEnqueue.once(DownloadOpenWeatherForecastJob, cooldown: 5.minutes)
    assert_equal 1, DownloadOpenWeatherForecastJob.jobs.size
  end
end

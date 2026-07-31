# frozen_string_literal: true

require Rails.root.join("lib/sentry_job_metrics")
require Rails.root.join("lib/sentry_sidekiq_stats_poller")

redis_config = {
  url: ENV["REDIS_URL"] || "redis://localhost:6379/0",
  ssl_params: {
    verify_mode: OpenSSL::SSL::VERIFY_NONE
  }
}

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.server_middleware do |chain|
    chain.add SentryJobMetrics
  end

  config.on(:startup) do
    SentrySidekiqStatsPoller.start!
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

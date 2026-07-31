# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
  config.release = ENV["SENTRY_RELEASE"].presence || ENV["HEROKU_SLUG_COMMIT"].presence
  config.spotlight = Rails.env.development?
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true

  config.enable_logs = true
  # Metrics are enabled by default (config.enable_metrics).

  # Auto check-ins for Sidekiq-Cron scheduled jobs.
  config.enabled_patches += [ :sidekiq_cron ]

  # Capture 100% in non-production; sample in production to control quota.
  config.traces_sample_rate = Rails.env.production? ? 0.2 : 1.0
end

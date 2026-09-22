# frozen_string_literal: true

Sentry.init do |config|
  sentry_env = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)

  config.dsn = ENV["SENTRY_DSN"]
  config.environment = sentry_env
  config.release = ENV["SENTRY_RELEASE"].presence || ENV["HEROKU_SLUG_COMMIT"].presence
  config.spotlight = Rails.env.development?
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true

  config.enable_logs = true
  # Metrics are enabled by default (config.enable_metrics).

  # Only register Sidekiq-Cron monitors in production — local Sidekiq otherwise
  # creates monitors that miss check-ins whenever the process stops.
  config.enabled_patches += [ :sidekiq_cron ] if sentry_env == "production"

  # Telebugs does not support tracing or profiling. nil (not 0.0) turns both
  # off: a numeric rate, including 0.0, still enables the tracer and continues
  # incoming traces.
  config.traces_sample_rate = nil
  config.profiles_sample_rate = nil
end

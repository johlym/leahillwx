# frozen_string_literal: true

# Periodically samples Sidekiq aggregate queue health into Sentry metrics.
# Started only inside the Sidekiq server process (see sidekiq initializer).
module SentrySidekiqStatsPoller
  INTERVAL_SECONDS = 30

  module_function

  def start!
    return if defined?(@started) && @started

    @started = true
    Thread.new do
      Thread.current.name = "sentry-sidekiq-stats"
      loop do
        report!
      rescue StandardError
        # Transient Redis/SDK errors should not kill the poller.
      ensure
        sleep INTERVAL_SECONDS
      end
    end
  end

  def report!
    stats = Sidekiq::Stats.new
    Sentry.metrics.gauge("sidekiq.enqueued", stats.enqueued)
    Sentry.metrics.gauge("sidekiq.retries", stats.retry_size)
    Sentry.metrics.gauge("sidekiq.dead", stats.dead_size)

    Sidekiq::Queue.all.first(10).each do |queue|
      attrs = { queue: queue.name }
      Sentry.metrics.gauge("sidekiq.queue.depth", queue.size, attributes: attrs)
      Sentry.metrics.gauge("sidekiq.queue.latency", queue.latency, unit: "second", attributes: attrs)
    end
  end
end

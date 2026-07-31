# frozen_string_literal: true

# Sidekiq server middleware that emits per-job duration / success / failure metrics.
class SentryJobMetrics
  def call(worker, _job, queue)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    attrs = { queue: queue, worker: worker.class.name }
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
    Sentry.metrics.distribution("sidekiq.job.duration", elapsed_ms, unit: "millisecond", attributes: attrs)
    Sentry.metrics.count("sidekiq.job.success", attributes: attrs)
  rescue StandardError
    Sentry.metrics.count(
      "sidekiq.job.failure",
      attributes: { queue: queue, worker: worker.class.name }
    )
    raise
  end
end

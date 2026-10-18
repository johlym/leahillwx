# frozen_string_literal: true

# Debounce Sidekiq enqueues so request-path refreshes cannot stampede Redis
# when many clients hit a stale homepage at once. Cron remains the source of truth.
module JobEnqueue
  module_function

  def once(job_class, *args, cooldown: 5.minutes)
    cooldown = 0 if Rails.env.test? && ENV["JOB_ENQUEUE_FORCE_COOLDOWN"].blank?

    if cooldown.to_i.positive?
      key = "job_enqueue:#{job_class.name}:#{Digest::SHA256.hexdigest(args.to_json)}"
      claimed = Sidekiq.redis do |conn|
        conn.set(key, Time.current.to_f.to_s, nx: true, ex: cooldown.to_i)
      end
      return false unless claimed
    end

    job_class.perform_async(*args)
    true
  end
end

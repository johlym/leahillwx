# frozen_string_literal: true

module WeatherMeasurements
  # Fast vanity counter for the footer "Measurement no." display.
  # Avoids SELECT COUNT(*) on the large weather_measurements table on every
  # create broadcast and homepage render.
  class TotalCount
    KEY = "weather_measurements:total_count"

    def self.read
      Sidekiq.redis do |redis|
        value = redis.get(redis_key)
        return Integer(value) if value

        count = WeatherMeasurement.count
        redis.set(redis_key, count)
        count
      end
    end

    def self.increment!(by: 1)
      return read if by.zero?

      Sidekiq.redis do |redis|
        if redis.get(redis_key)
          redis.incrby(redis_key, by).to_i
        else
          count = WeatherMeasurement.count
          redis.set(redis_key, count)
          count
        end
      end
    end

    def self.recalculate!
      count = WeatherMeasurement.count
      Sidekiq.redis { |redis| redis.set(redis_key, count) }
      count
    end

    def self.clear!
      Sidekiq.redis { |redis| redis.del(redis_key) }
    end

    # Public so tests can assert against the namespaced key under parallelization.
    def self.redis_key
      return KEY unless Rails.env.test?

      "#{KEY}:#{test_worker_id}"
    end

    def self.test_worker_id
      if ActiveSupport::TestCase.respond_to?(:parallel_worker_id) &&
          !ActiveSupport::TestCase.parallel_worker_id.nil?
        return ActiveSupport::TestCase.parallel_worker_id
      end

      number = ENV.fetch("TEST_ENV_NUMBER", "0")
      number.empty? ? "0" : number
    end
    private_class_method :test_worker_id
  end
end

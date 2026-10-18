# frozen_string_literal: true

class Rack::Attack
  Rack::Attack.cache.store =
    if Rails.env.test?
      ActiveSupport::Cache::MemoryStore.new
    else
      ActiveSupport::Cache::RedisCacheStore.new(
        url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
      )
    end

  throttle("api/ip", limit: 120, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  throttle("api/measurement_writes", limit: 60, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{\A/api/v1/weather_measurement})
      req.ip
    end
  end

  throttle("celestial/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/celestial")
  end

  throttle("docs/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/docs")
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Rate limit exceeded. Try again shortly." }.to_json ]
    ]
  end
end

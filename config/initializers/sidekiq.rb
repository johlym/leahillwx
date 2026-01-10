Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV["REDIS_URL"] || "redis://localhost:6379/0", # Use your Redis URL environment variable
    ssl_params: {
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV["REDIS_URL"] || "redis://localhost:6379/0", # Use your Redis URL environment variable
    ssl_params: {
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  }
end

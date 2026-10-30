# frozen_string_literal: true

require "test_helper"

class ActionCableRedisAdapterTest < ActiveSupport::TestCase
  REDIS_URL = "redis://localhost:6379/1"

  test "redis pubsub adapter loads and publishes when redis 6 is already activated" do
    gem "redis", ">= 5.4"
    require "redis"
    assert_operator Gem::Version.new(Redis::VERSION), :>=, Gem::Version.new("6.0.0")
    assert_operator Gem::Version.new(Redis::VERSION), :<, Gem::Version.new("7.0.0")

    config = ActionCable::Server::Configuration.new
    config.logger = Logger.new(IO::NULL)
    config.cable = {
      "adapter" => "redis",
      "url" => REDIS_URL,
      "channel_prefix" => "leahillwx_test"
    }.with_indifferent_access

    assert_equal ActionCable::SubscriptionAdapter::Redis, config.pubsub_adapter

    channel = "weather_measurements_#{SecureRandom.hex(4)}"
    prefixed = "leahillwx_test:#{channel}"
    payload = %(<turbo-stream action="weather_update" data="{}"><template></template></turbo-stream>)
    received = Queue.new
    subscriber = Thread.new do
      Redis.new(url: REDIS_URL).subscribe(prefixed) do |on|
        on.subscribe { received << :ready }
        on.message do |_channel, message|
          received << message
          on.unsubscribe
        end
      end
    end

    assert_equal :ready, Timeout.timeout(2) { received.pop }

    server = ActionCable::Server::Base.new(config: config)
    server.broadcast(channel, payload)

    assert_equal payload, JSON.parse(Timeout.timeout(2) { received.pop })
  ensure
    subscriber&.join(2)
  end
end

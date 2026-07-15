require "test_helper"

class OpenWeatherClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  setup do
    @service = OpenWeatherClient.new
    @original_get = HTTParty.method(:get)
  end

  teardown do
    HTTParty.define_singleton_method(:get, @original_get)
  end

  test "retrieve_forecast returns parsed JSON on success" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: { "lat" => 47.0 }.to_json)
    end

    result = @service.retrieve_forecast

    assert_equal 47.0, result["lat"]
  end

  test "retrieve_forecast raises on non-success status" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 500, body: "error")
    end

    assert_raises(OpenWeatherClient::RequestError) do
      @service.retrieve_forecast
    end
  end

  test "retrieve_forecast passes timeout to HTTParty" do
    captured = nil
    HTTParty.define_singleton_method(:get) do |*_args, **kwargs|
      captured = kwargs
      FakeResponse.new(code: 200, body: "{}")
    end

    @service.retrieve_forecast

    assert_equal HttpClient::DEFAULT_TIMEOUT, captured[:timeout]
  end
end

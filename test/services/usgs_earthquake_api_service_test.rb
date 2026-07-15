require "test_helper"

class UsgsEarthquakeApiServiceTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  setup do
    @service = UsgsEarthquakeApiService.new
    @original_get = HTTParty.method(:get)
  end

  teardown do
    HTTParty.define_singleton_method(:get, @original_get)
  end

  test "get_latest_earthquake returns nil when features are empty" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: { "features" => [] }.to_json)
    end

    assert_nil @service.get_latest_earthquake
  end

  test "get_latest_earthquake returns nil for blank body" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 204, body: "")
    end

    assert_nil @service.get_latest_earthquake
  end

  test "get_latest_earthquake parses the first feature" do
    payload = {
      "features" => [
        {
          "id" => "us7000abcd",
          "properties" => {
            "mag" => 3.1,
            "place" => "Somewhere, CA",
            "time" => 1_710_000_000_000,
            "updated" => 1_710_000_100_000,
            "url" => "https://example.com"
          },
          "geometry" => { "coordinates" => [ -122.0, 47.0, 10.0 ] }
        }
      ]
    }

    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: payload.to_json)
    end

    result = @service.get_latest_earthquake

    assert_equal "us7000abcd", result[:usgs_id]
    assert_equal 3.1, result[:magnitude]
    assert_equal 47.0, result[:lat]
  end
end

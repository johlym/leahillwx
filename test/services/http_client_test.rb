require "test_helper"

class HttpClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  setup do
    @original_get = HTTParty.method(:get)
  end

  teardown do
    HTTParty.define_singleton_method(:get, @original_get)
  end

  test "get_json returns parsed body" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: { "ok" => true }.to_json)
    end

    assert_equal({ "ok" => true }, HttpClient.get_json("https://example.com"))
  end

  test "get raises RequestError on failure status" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 503, body: "unavailable")
    end

    assert_raises(HttpClient::RequestError) do
      HttpClient.get("https://example.com")
    end
  end
end

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

  test "get wraps network timeouts as RequestError" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      raise Net::OpenTimeout, "execution expired"
    end

    error = assert_raises(HttpClient::RequestError) do
      HttpClient.get("https://example.com")
    end
    assert_match(/Net::OpenTimeout/, error.message)
  end

  test "get wraps connection resets as RequestError" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      raise Errno::ECONNRESET, "Connection reset by peer"
    end

    error = assert_raises(HttpClient::RequestError) do
      HttpClient.get("https://example.com")
    end
    assert_match(/ECONNRESET/, error.message)
  end

  test "get_json wraps invalid JSON as RequestError" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: '{"incomplete":')
    end

    error = assert_raises(HttpClient::RequestError) do
      HttpClient.get_json("https://example.com")
    end
    assert_match(/invalid JSON/, error.message)
  end
end

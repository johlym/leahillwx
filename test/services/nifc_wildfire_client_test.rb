# frozen_string_literal: true

require "test_helper"

class NifcWildfireClientTest < ActiveSupport::TestCase
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

  test "queries current wildfires that are not declared out" do
    captured = nil
    HTTParty.define_singleton_method(:get) do |_url, **kwargs|
      captured = kwargs[:query]
      FakeResponse.new(code: 200, body: { "features" => [] }.to_json)
    end

    NifcWildfireClient.new.active_fires

    assert_includes captured[:where], "IncidentTypeCategory = 'WF'"
    assert_includes captured[:where], "FireOutDateTime IS NULL"
    assert_includes captured[:where], "POOState = 'US-WA'"
  end
end

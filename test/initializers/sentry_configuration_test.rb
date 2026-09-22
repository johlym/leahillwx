# frozen_string_literal: true

require "test_helper"

class SentryConfigurationTest < ActiveSupport::TestCase
  test "tracing and profiling are disabled for Telebugs" do
    config = Sentry.configuration

    assert_nil config.traces_sample_rate
    assert_nil config.traces_sampler
    assert_nil config.profiles_sample_rate
    assert_not config.tracing_enabled?
    assert_not config.profiling_enabled?
  end
end

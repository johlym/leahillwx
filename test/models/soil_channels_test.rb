# frozen_string_literal: true

require "test_helper"

class SoilChannelsTest < ActiveSupport::TestCase
  setup do
    SoilChannels.config_path = nil
    SoilChannels.reload!
  end

  teardown do
    SoilChannels.config_path = nil
    SoilChannels.reload!
  end

  test "falls back to Ch N when channel is unnamed" do
    assert_equal "Ch 1", SoilChannels.name_for(1)
    assert_equal "Ch 8", SoilChannels.name_for(8)
  end

  test "returns configured friendly name" do
    with_soil_channel_names(1 => "Raised bed", 2 => "Tomato pots") do
      assert_equal "Raised bed", SoilChannels.name_for(1)
      assert_equal "Tomato pots", SoilChannels.name_for(2)
      assert_equal "Ch 3", SoilChannels.name_for(3)
    end
  end

  test "accepts string channel numbers" do
    with_soil_channel_names(1 => "Raised bed") do
      assert_equal "Raised bed", SoilChannels.name_for("1")
    end
  end

  test "loads names from yaml config" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("soil_channels.yml")
      path.write({ 1 => "Raised bed", 2 => "Tomato pots" }.to_yaml)

      SoilChannels.config_path = path
      SoilChannels.reload!

      assert_equal "Raised bed", SoilChannels.name_for(1)
      assert_equal "Tomato pots", SoilChannels.name_for(2)
      assert_equal "Ch 3", SoilChannels.name_for(3)
    end
  end

  private

  def with_soil_channel_names(names)
    SoilChannels.instance_variable_set(:@names, names)
    yield
  ensure
    SoilChannels.reload!
  end
end

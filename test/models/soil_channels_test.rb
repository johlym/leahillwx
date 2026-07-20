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

  test "falls back to Ch N for unnamed soil channels" do
    with_soil_maps(soil: {}, temp_probe: {}) do
      assert_equal "Ch 1", SoilChannels.name_for_soil(1)
      assert_equal "Ch 8", SoilChannels.name_for_soil(8)
    end
  end

  test "falls back to Temp Ch N for unnamed temp probe channels" do
    with_soil_maps(soil: {}, temp_probe: {}) do
      assert_equal "Temp Ch 1", SoilChannels.name_for_temp_probe(1)
      assert_equal "Temp Ch 8", SoilChannels.name_for_temp_probe(8)
    end
  end

  test "returns configured friendly names for soil and temp probes" do
    with_soil_maps(
      soil: { 1 => "Front Yard" },
      temp_probe: { 2 => "Front Yard", 3 => "Back Bed" }
    ) do
      assert_equal "Front Yard", SoilChannels.name_for_soil(1)
      assert_equal "Front Yard", SoilChannels.name_for_temp_probe(2)
      assert_equal "Back Bed", SoilChannels.name_for_temp_probe(3)
      assert_equal "Ch 2", SoilChannels.name_for_soil(2)
      assert_equal "Temp Ch 1", SoilChannels.name_for_temp_probe(1)
    end
  end

  test "accepts string channel numbers" do
    with_soil_maps(soil: { 1 => "Raised bed" }, temp_probe: { 2 => "Raised bed" }) do
      assert_equal "Raised bed", SoilChannels.name_for_soil("1")
      assert_equal "Raised bed", SoilChannels.name_for_temp_probe("2")
    end
  end

  test "loads group-centric yaml config" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("soil_channels.yml")
      path.write(<<~YAML)
        Front Yard:
          soil: 1
          temp_probe: 2
        Veggie Bed:
          soil: 3
        Shade Bed:
          temp_probe: 4
      YAML

      SoilChannels.config_path = path
      SoilChannels.reload!

      assert_equal "Front Yard", SoilChannels.name_for_soil(1)
      assert_equal "Front Yard", SoilChannels.name_for_temp_probe(2)
      assert_equal "Veggie Bed", SoilChannels.name_for_soil(3)
      assert_equal "Shade Bed", SoilChannels.name_for_temp_probe(4)
      assert_equal "Ch 2", SoilChannels.name_for_soil(2)
      assert_equal "Temp Ch 1", SoilChannels.name_for_temp_probe(1)
    end
  end

  test "name_for aliases soil lookup" do
    with_soil_maps(soil: { 1 => "Raised bed" }, temp_probe: {}) do
      assert_equal "Raised bed", SoilChannels.name_for(1)
    end
  end

  private

  def with_soil_maps(soil:, temp_probe:)
    SoilChannels.instance_variable_set(:@soil_names, soil)
    SoilChannels.instance_variable_set(:@temp_probe_names, temp_probe)
    yield
  ensure
    SoilChannels.reload!
  end
end

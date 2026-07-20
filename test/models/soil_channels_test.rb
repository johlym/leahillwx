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

  test "loads committed site soil_channels.yml groupings" do
    SoilChannels.config_path = Rails.root.join("config/soil_channels.yml")
    SoilChannels.reload!

    assert_equal "Veggie Bed", SoilChannels.name_for_soil(1)
    assert_equal "Front Yard", SoilChannels.name_for_soil(2)
    assert_equal "Front Yard", SoilChannels.name_for_temp_probe(2)
    assert_equal "Back Yard", SoilChannels.name_for_soil(3)
    assert_equal "Back Yard", SoilChannels.name_for_temp_probe(1)
  end

  test "rejects legacy channel-keyed yaml" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("soil_channels.yml")
      path.write({ 1 => "Veggie Bed", 2 => "Front Yard" }.to_yaml)

      SoilChannels.config_path = path

      error = assert_raises(ArgumentError) { SoilChannels.reload! }
      assert_match(/no longer supported/, error.message)
    end
  end

  test "rejects duplicate soil channel mappings" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("soil_channels.yml")
      path.write(<<~YAML)
        Front Yard:
          soil: 1
        Veggie Bed:
          soil: 1
      YAML

      SoilChannels.config_path = path

      error = assert_raises(ArgumentError) { SoilChannels.reload! }
      assert_match(/soil channel 1 is already mapped/, error.message)
    end
  end

  test "rejects out-of-range channel mappings" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("soil_channels.yml")
      path.write(<<~YAML)
        Front Yard:
          temp_probe: 9
      YAML

      SoilChannels.config_path = path

      error = assert_raises(ArgumentError) { SoilChannels.reload! }
      assert_match(/expected integer 1/, error.message)
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

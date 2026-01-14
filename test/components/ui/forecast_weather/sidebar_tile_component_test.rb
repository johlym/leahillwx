# frozen_string_literal: true

require "test_helper"

class Ui::ForecastWeather::GenericTileComponentTest < ViewComponent::TestCase
  def test_renders_generic_tile_container
    component = Ui::ForecastWeather::GenericTileComponent.new

    render_inline(component) { "Test content" }

    assert_selector "div.generic-tile"
  end

  def test_renders_with_heading
    component = Ui::ForecastWeather::GenericTileComponent.new(heading: "Test Heading")

    render_inline(component) { "Test content" }

    assert_selector "h2.weather-tile-heading", text: "Test Heading"
  end

  def test_renders_without_heading_when_nil
    component = Ui::ForecastWeather::GenericTileComponent.new(heading: nil)

    render_inline(component) { "Test content" }

    assert_no_selector "h2.weather-tile-heading"
  end

  def test_renders_without_heading_when_omitted
    component = Ui::ForecastWeather::GenericTileComponent.new

    render_inline(component) { "Test content" }

    assert_no_selector "h2.weather-tile-heading"
  end

  def test_renders_without_heading_when_blank
    component = Ui::ForecastWeather::GenericTileComponent.new(heading: "")

    render_inline(component) { "Test content" }

    assert_no_selector "h2.weather-tile-heading"
  end

  def test_renders_content_area
    component = Ui::ForecastWeather::GenericTileComponent.new

    render_inline(component) { "Test content" }

    assert_selector "div.weather-tile-content"
  end

  def test_renders_provided_content
    component = Ui::ForecastWeather::GenericTileComponent.new

    render_inline(component) { "Custom content here" }

    assert_selector "div.weather-tile-content", text: "Custom content here"
  end

  def test_renders_html_content
    component = Ui::ForecastWeather::GenericTileComponent.new(heading: "HTML Test")

    render_inline(component) do
      '<div class="custom-content"><p>Paragraph 1</p><p>Paragraph 2</p></div>'.html_safe
    end

    assert_selector "div.weather-tile-content div.custom-content"
    assert_selector "div.weather-tile-content p", text: "Paragraph 1"
    assert_selector "div.weather-tile-content p", text: "Paragraph 2"
  end

  def test_heading_attribute_reader
    component = Ui::ForecastWeather::GenericTileComponent.new(heading: "My Heading")

    assert_equal "My Heading", component.heading
  end

  def test_heading_attribute_reader_when_nil
    component = Ui::ForecastWeather::GenericTileComponent.new

    assert_nil component.heading
  end

  def test_multiple_tiles_render_independently
    component1 = Ui::ForecastWeather::GenericTileComponent.new(heading: "Tile 1")
    component2 = Ui::ForecastWeather::GenericTileComponent.new(heading: "Tile 2")

    result1 = render_inline(component1) { "Content 1" }
    result2 = render_inline(component2) { "Content 2" }

    assert_includes result1.css("h2.weather-tile-heading").text, "Tile 1"
    assert_includes result2.css("h2.weather-tile-heading").text, "Tile 2"
  end
end

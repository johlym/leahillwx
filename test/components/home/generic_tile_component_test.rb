# frozen_string_literal: true

require "test_helper"

class Home::GenericTileComponentTest < ViewComponent::TestCase
  def test_renders_generic_tile_container
    render_inline(Home::GenericTileComponent.new) { "Test content" }

    assert_selector "section.ui-card.generic-tile"
  end

  def test_renders_with_heading
    render_inline(Home::GenericTileComponent.new(heading: "Test Heading")) { "Test content" }

    assert_selector "section.generic-tile header h2", text: "Test Heading"
  end

  def test_renders_with_subtitle
    render_inline(Home::GenericTileComponent.new(heading: "Wind", subtitle: "Right now")) { "Test content" }

    assert_selector "section.generic-tile header h2", text: "Wind"
    assert_selector "section.generic-tile header p", text: "Right now"
  end

  def test_renders_without_heading_when_nil
    render_inline(Home::GenericTileComponent.new(heading: nil)) { "Test content" }

    assert_no_selector "section.generic-tile header h2"
  end

  def test_renders_without_heading_when_omitted
    render_inline(Home::GenericTileComponent.new) { "Test content" }

    assert_no_selector "section.generic-tile header h2"
  end

  def test_renders_without_heading_when_blank
    render_inline(Home::GenericTileComponent.new(heading: "")) { "Test content" }

    assert_no_selector "section.generic-tile header h2"
  end

  def test_renders_provided_content
    render_inline(Home::GenericTileComponent.new) { "Custom content here" }

    assert_selector "section.generic-tile", text: "Custom content here"
  end

  def test_renders_html_content
    render_inline(Home::GenericTileComponent.new(heading: "HTML Test")) do
      '<div class="custom-content"><p>Paragraph 1</p><p>Paragraph 2</p></div>'.html_safe
    end

    assert_selector "section.generic-tile div.custom-content"
    assert_selector "section.generic-tile p", text: "Paragraph 1"
    assert_selector "section.generic-tile p", text: "Paragraph 2"
  end

  def test_heading_attribute_reader
    component = Home::GenericTileComponent.new(heading: "My Heading")

    assert_equal "My Heading", component.heading
  end

  def test_heading_attribute_reader_when_nil
    component = Home::GenericTileComponent.new

    assert_nil component.heading
  end

  def test_subtitle_attribute_reader
    component = Home::GenericTileComponent.new(subtitle: "A subtitle")

    assert_equal "A subtitle", component.subtitle
  end

  def test_multiple_tiles_render_independently
    component1 = Home::GenericTileComponent.new(heading: "Tile 1")
    component2 = Home::GenericTileComponent.new(heading: "Tile 2")

    result1 = render_inline(component1) { "Content 1" }
    result2 = render_inline(component2) { "Content 2" }

    assert_includes result1.css("h2").text, "Tile 1"
    assert_includes result2.css("h2").text, "Tile 2"
  end
end

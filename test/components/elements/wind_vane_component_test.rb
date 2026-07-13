# frozen_string_literal: true

require "test_helper"

class Elements::WindVaneComponentTest < ViewComponent::TestCase
  test "renders wind vane icon with correct rotation" do
    render_inline(Elements::WindVaneComponent.new(direction: 90))

    assert_selector "i.fa-location-arrow-up"
    assert_selector "i[style*='rotate(90deg)']"
  end

  test "renders with zero degree rotation" do
    render_inline(Elements::WindVaneComponent.new(direction: 0))

    assert_selector "i[style*='rotate(0deg)']"
  end

  test "renders with 180 degree rotation" do
    render_inline(Elements::WindVaneComponent.new(direction: 180))

    assert_selector "i[style*='rotate(180deg)']"
  end

  test "renders with 270 degree rotation" do
    render_inline(Elements::WindVaneComponent.new(direction: 270))

    assert_selector "i[style*='rotate(270deg)']"
  end

  test "renders with FontAwesome classes" do
    render_inline(Elements::WindVaneComponent.new(direction: 45))

    assert_selector "i.fa-fw"
    assert_selector "i.fa-sharp-duotone"
    assert_selector "i.fa-solid"
    assert_selector "i.fa-location-arrow-up"
    assert_selector "i.wind-vane"
  end

  test "sets aria-label with rounded direction" do
    render_inline(Elements::WindVaneComponent.new(direction: 137.6))

    assert_selector "i[aria-label='138 degrees']"
  end

  test "exposes role='img' for accessibility" do
    render_inline(Elements::WindVaneComponent.new(direction: 0))

    assert_selector "i[role='img']"
  end

  test "renders nothing when direction is nil" do
    render_inline(Elements::WindVaneComponent.new(direction: nil))

    assert_no_selector "i.wind-vane"
  end
end

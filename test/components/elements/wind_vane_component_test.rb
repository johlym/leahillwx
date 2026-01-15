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
    assert_selector "i.fa-light"
  end
end

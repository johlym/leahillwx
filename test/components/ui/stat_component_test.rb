# frozen_string_literal: true

require "test_helper"

class Ui::StatComponentTest < ViewComponent::TestCase
  test "renders the value" do
    render_inline(Ui::StatComponent.new(value: "72"))

    assert_selector "span", text: "72"
  end

  test "renders label when provided" do
    render_inline(Ui::StatComponent.new(value: "72", label: "High"))

    assert_selector "span", text: "High"
  end

  test "omits label block when label is blank" do
    render_inline(Ui::StatComponent.new(value: "72"))

    assert_no_selector "div.inline-flex.items-center span"
  end

  test "renders unit alongside the value when provided" do
    render_inline(Ui::StatComponent.new(value: "72", unit: "°F"))

    assert_selector "span", text: "72"
    assert_selector "span", text: "°F"
  end

  test "renders secondary line when provided" do
    render_inline(Ui::StatComponent.new(value: "72", secondary: "vs. avg 68°F"))

    assert_selector "p", text: "vs. avg 68°F"
  end

  test "omits secondary line when blank" do
    render_inline(Ui::StatComponent.new(value: "72"))

    assert_no_selector "p"
  end

  test "renders label icon when both label and icon are provided" do
    render_inline(Ui::StatComponent.new(value: "72", label: "High", icon: "fa-solid fa-sun"))

    assert_selector "i.fa-solid.fa-sun"
  end

  test "does not render label icon when label is blank" do
    render_inline(Ui::StatComponent.new(value: "72", icon: "fa-solid fa-sun"))

    assert_no_selector "i.fa-solid.fa-sun"
  end

  test "renders up trend with success color and up arrow" do
    render_inline(Ui::StatComponent.new(value: "72", trend: :up, trend_label: "+2°"))

    assert_selector "p.text-success i.fa-arrow-trend-up"
    assert_selector "p", text: "+2°"
  end

  test "renders down trend with danger color and down arrow" do
    render_inline(Ui::StatComponent.new(value: "72", trend: :down, trend_label: "-1°"))

    assert_selector "p.text-danger i.fa-arrow-trend-down"
  end

  test "renders flat trend with muted color and minus icon" do
    render_inline(Ui::StatComponent.new(value: "72", trend: :flat, trend_label: "no change"))

    assert_selector "p.text-muted i.fa-minus"
  end

  test "falls back to flat trend styling for unknown trend values" do
    render_inline(Ui::StatComponent.new(value: "72", trend: :sideways, trend_label: "flat-ish"))

    assert_selector "p.text-muted i.fa-minus"
  end

  test "applies known size class" do
    render_inline(Ui::StatComponent.new(value: "72", size: :xl))

    assert_selector "div.text-7xl"
  end

  test "falls back to md size for unknown size" do
    render_inline(Ui::StatComponent.new(value: "72", size: :ginormous))

    assert_selector "div.text-4xl"
  end

  test "applies center alignment classes" do
    render_inline(Ui::StatComponent.new(value: "72", align: :center))

    assert_selector "div.items-center.text-center"
  end

  test "falls back to left alignment for unknown alignment" do
    render_inline(Ui::StatComponent.new(value: "72", align: :diagonal))

    assert_selector "div.items-start.text-left"
  end
end

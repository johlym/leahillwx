# frozen_string_literal: true

require "test_helper"

class Ui::TabsComponentTest < ViewComponent::TestCase
  def items
    [
      { id: :sun,  label: "Sun",  icon: "far fa-sun",  action: "click->almanac-table-toggle#showSun" },
      { id: :moon, label: "Moon", icon: "far fa-moon", action: "click->almanac-table-toggle#showMoon" }
    ]
  end

  test "renders a tablist container" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "div.ui-tabs[role='tablist']"
  end

  test "renders a button for each item with role='tab'" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "button[type='button'][role='tab'].ui-tabs-tab", count: 2
  end

  test "renders each item's label" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "button.ui-tabs-tab", text: "Sun"
    assert_selector "button.ui-tabs-tab", text: "Moon"
  end

  test "renders icons when items provide them" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "button.ui-tabs-tab i.far.fa-sun"
    assert_selector "button.ui-tabs-tab i.far.fa-moon"
  end

  test "marks the current item as active with aria-selected='true'" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "button.ui-tabs-tab.ui-tabs-tab-active[aria-selected='true']", text: "Sun"
    assert_selector "button.ui-tabs-tab[aria-selected='false']", text: "Moon"
    assert_no_selector "button[aria-selected='true']", text: "Moon"
  end

  test "compares current using string equality (symbol vs string)" do
    string_items = [ { id: "sun", label: "Sun" }, { id: "moon", label: "Moon" } ]
    render_inline(Ui::TabsComponent.new(items: string_items, current: :sun))

    assert_selector "button.ui-tabs-tab-active", text: "Sun"
  end

  test "marks nothing active when current is nil" do
    render_inline(Ui::TabsComponent.new(items: items, current: nil))

    assert_no_selector "button.ui-tabs-tab-active"
    assert_selector "button[aria-selected='false']", count: 2
  end

  test "wires up data-action from item :action" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "button[data-action='click->almanac-table-toggle#showSun']", text: "Sun"
    assert_selector "button[data-action='click->almanac-table-toggle#showMoon']", text: "Moon"
  end

  test "prefers item :data over :action when both are present" do
    items_with_data = [
      {
        id: :one, label: "One",
        action: "click->old#handler",
        data: { action: "click->new#handler", "custom-attr": "yes" }
      }
    ]
    render_inline(Ui::TabsComponent.new(items: items_with_data, current: :one))

    assert_selector "button[data-action='click->new#handler']"
    assert_selector "button[data-custom-attr='yes']"
    assert_no_selector "button[data-action='click->old#handler']"
  end

  test "applies small variant class when size is :sm" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun, size: :sm))

    assert_selector "div.ui-tabs.ui-tabs-sm"
  end

  test "omits size modifier for :md (default) size" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun))

    assert_selector "div.ui-tabs"
    assert_no_selector "div.ui-tabs-sm"
  end

  test "falls back to :md when size is unrecognized" do
    render_inline(Ui::TabsComponent.new(items: items, current: :sun, size: :ginormous))

    assert_no_selector "div.ui-tabs-sm"
  end
end

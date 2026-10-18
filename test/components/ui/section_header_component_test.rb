# frozen_string_literal: true

require "test_helper"

class Ui::SectionHeaderComponentTest < ViewComponent::TestCase
  test "renders title inside default h2" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Records"))

    assert_selector "div.ui-section-header h2", text: "Records"
  end

  test "renders subtitle when provided" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Records", subtitle: "All-time"))

    assert_selector "h2", text: "Records"
    assert_selector "p", text: "All-time"
  end

  test "omits subtitle when blank" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Records"))

    assert_no_selector "div.ui-section-header p"
  end

  test "marks a level-1 header as a page title container" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Climatological Summary", level: 1))

    assert_selector "div.ui-section-header.ui-section-header-page h1"
  end

  test "does not mark lower headings as page titles" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Trends", level: 2))

    assert_selector "div.ui-section-header"
    assert_no_selector "div.ui-section-header-page"
  end

  test "renders heading at the requested level" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Trends", level: 3))

    assert_selector "h3", text: "Trends"
    assert_no_selector "h2", text: "Trends"
  end

  test "falls back to h2 for unsupported heading levels" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Trends", level: 7))

    assert_selector "h2", text: "Trends"
  end

  test "renders an icon inside the heading when provided" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Almanac", icon: "fa-solid fa-book"))

    assert_selector "h2 i.fa-solid.fa-book"
    assert_selector "h2", text: "Almanac"
  end

  test "renders actions slot content" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Records")) do |header|
      header.with_actions { '<button class="year-picker">2024</button>'.html_safe }
    end

    assert_selector "div.ui-section-header button.year-picker", text: "2024"
  end

  test "does not render actions wrapper when slot is empty" do
    render_inline(Ui::SectionHeaderComponent.new(title: "Records"))

    assert_no_selector "div.ui-section-header button"
  end
end

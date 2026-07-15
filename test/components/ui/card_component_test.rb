# frozen_string_literal: true

require "test_helper"

class Ui::CardComponentTest < ViewComponent::TestCase
  test "renders as a section by default with ui-card class" do
    render_inline(Ui::CardComponent.new) { "body" }

    assert_selector "section.ui-card", text: "body"
  end

  test "renders with a custom root tag when :as is provided" do
    render_inline(Ui::CardComponent.new(as: :article)) { "body" }

    assert_selector "article.ui-card"
    assert_no_selector "section.ui-card"
  end

  test "renders title and subtitle in header when provided" do
    render_inline(Ui::CardComponent.new(title: "Wind", subtitle: "Right now")) { "body" }

    assert_selector "header h2", text: "Wind"
    assert_selector "header p", text: "Right now"
  end

  test "omits header entirely when there is no title, subtitle, or actions" do
    render_inline(Ui::CardComponent.new) { "body" }

    assert_no_selector "header"
  end

  test "renders icon inside the title when provided" do
    render_inline(Ui::CardComponent.new(title: "Wind", icon: "fa-solid fa-wind")) { "body" }

    assert_selector "header h2 i.fa-solid.fa-wind"
    assert_selector "header h2", text: "Wind"
  end

  test "renders actions slot inside the header" do
    render_inline(Ui::CardComponent.new(title: "Records")) do |card|
      card.with_actions { '<a href="#" class="details-link">Details</a>'.html_safe }
      "body"
    end

    assert_selector "header a.details-link", text: "Details"
  end

  test "renders footer slot when provided" do
    render_inline(Ui::CardComponent.new) do |card|
      card.with_footer { "Updated just now" }
      "body"
    end

    assert_selector "footer", text: "Updated just now"
  end

  test "does not render footer element when footer slot is absent" do
    render_inline(Ui::CardComponent.new) { "body" }

    assert_no_selector "footer"
  end

  test "applies the variant class for known variants" do
    render_inline(Ui::CardComponent.new(variant: :subtle)) { "body" }

    assert_selector ".ui-card.ui-card-subtle"
  end

  test "falls back to default variant for unknown variant" do
    render_inline(Ui::CardComponent.new(variant: :bogus)) { "body" }

    assert_selector "section.ui-card"
    assert_no_selector ".ui-card-subtle"
    assert_no_selector ".ui-card-emphasis"
  end

  test "applies the padding class for known padding values" do
    render_inline(Ui::CardComponent.new(padding: :tight)) { "body" }

    assert_selector ".ui-card.ui-card-pad-tight"
  end

  test "falls back to default padding for unknown padding" do
    render_inline(Ui::CardComponent.new(padding: :huge)) { "body" }

    assert_selector ".ui-card.ui-card-pad-default"
  end

  test "appends caller-provided extra classes to the root" do
    render_inline(Ui::CardComponent.new(classes: "my-extra another-one")) { "body" }

    assert_selector "section.ui-card.my-extra.another-one"
  end
end

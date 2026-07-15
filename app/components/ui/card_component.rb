# frozen_string_literal: true

# Standard elevated surface used across the app. Composable via slots:
#
#   <%= render Ui::CardComponent.new(title: "Wind") do |c| %>
#     <% c.with_actions do %><%= link_to "Details", "#" %><% end %>
#     ... body ...
#   <% end %>
module Ui
  class CardComponent < ViewComponent::Base
    renders_one :actions
    renders_one :footer

    VARIANTS = { default: nil, subtle: "ui-card-subtle", emphasis: "ui-card-emphasis" }.freeze
    PADDING  = {
      none: "ui-card-pad-none",
      tight: "ui-card-pad-tight",
      default: "ui-card-pad-default",
      loose: "ui-card-pad-loose"
    }.freeze

    def initialize(
      title: nil,
      subtitle: nil,
      icon: nil,
      variant: :default,
      padding: :default,
      classes: nil,
      as: :section
    )
      @title = title
      @subtitle = subtitle
      @icon = icon
      @variant = VARIANTS.key?(variant) ? variant : :default
      @padding = PADDING.key?(padding) ? padding : :default
      @extra_classes = classes
      @tag = as
    end

    def call
      content_tag(@tag, class: root_classes) do
        safe_join([ header_content, body_content, footer_content ].compact)
      end
    end

    private

    attr_reader :title, :subtitle, :icon, :variant, :padding, :extra_classes

    def root_classes
      [
        "ui-card",
        VARIANTS[variant],
        PADDING[padding],
        extra_classes
      ].compact.reject(&:empty?).join(" ")
    end

    def header?
      title.present? || subtitle.present? || actions?
    end

    def header_content
      return nil unless header?

      content_tag(:header, class: "ui-card-header") do
        safe_join([
          title_block,
          actions? ? content_tag(:div, actions, class: "ui-card-actions") : nil
        ].compact)
      end
    end

    def title_block
      return nil unless title.present? || subtitle.present?

      content_tag(:div, class: "ui-card-header-text") do
        safe_join([
          title.present? ? content_tag(:h2, title_with_icon, class: "ui-card-title") : nil,
          subtitle.present? ? content_tag(:p, subtitle, class: "ui-card-subtitle") : nil
        ].compact)
      end
    end

    def title_with_icon
      if icon.present?
        safe_join([ content_tag(:i, "", class: icon), title ], " ")
      else
        title
      end
    end

    def body_content
      content_tag(:div, content, class: "ui-card-body")
    end

    def footer_content
      return nil unless footer?

      content_tag(:footer, footer, class: "ui-card-footer")
    end
  end
end

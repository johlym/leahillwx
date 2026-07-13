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
    PADDING  = { none: "p-0", tight: "p-3", default: "p-5", loose: "p-6" }.freeze

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

      content_tag(:header, class: "flex items-start justify-between gap-4 mb-3") do
        safe_join([
          title_block,
          actions? ? content_tag(:div, actions, class: "flex items-center gap-2 shrink-0") : nil
        ].compact)
      end
    end

    def title_block
      return nil unless title.present? || subtitle.present?

      content_tag(:div, class: "min-w-0") do
        safe_join([
          title.present? ? content_tag(:h2, title_with_icon, class: "font-condensed uppercase tracking-[0.04em] text-[1.05rem] text-text-strong") : nil,
          subtitle.present? ? content_tag(:p, subtitle, class: "mt-[0.15rem] text-xs text-muted") : nil
        ].compact)
      end
    end

    def title_with_icon
      if icon.present?
        safe_join([ content_tag(:i, "", class: "#{icon} mr-[0.35rem] text-accent"), title ], " ")
      else
        title
      end
    end

    def body_content
      content_tag(:div, content, class: "text-text")
    end

    def footer_content
      return nil unless footer?

      content_tag(:footer, footer, class: "mt-4 pt-3 border-t border-border text-xs text-muted")
    end
  end
end

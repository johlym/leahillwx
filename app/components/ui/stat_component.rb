# frozen_string_literal: true

# Big value + label + optional secondary line and trend indicator.
# Used for current-conditions tiles, records cards, and trends anomalies.
module Ui
  class StatComponent < ViewComponent::Base
    SIZE_CLASSES = {
      sm: "ui-stat-value-sm",
      md: "ui-stat-value-md",
      lg: "ui-stat-value-lg",
      xl: "ui-stat-value-xl"
    }.freeze

    ALIGN_CLASSES = {
      left:   "ui-stat-left",
      center: "ui-stat-center",
      right:  "ui-stat-right"
    }.freeze

    TREND_CLASSES = {
      up:   { icon: "fa-arrow-trend-up",   color: "ui-stat-trend-up" },
      down: { icon: "fa-arrow-trend-down", color: "ui-stat-trend-down" },
      flat: { icon: "fa-minus",            color: "ui-stat-trend-flat" }
    }.freeze

    def initialize(
      value:,
      label: nil,
      unit: nil,
      secondary: nil,
      icon: nil,
      trend: nil,
      trend_label: nil,
      size: :md,
      align: :left
    )
      @value = value
      @label = label
      @unit = unit
      @secondary = secondary
      @icon = icon
      @trend = trend
      @trend_label = trend_label
      @size = SIZE_CLASSES.key?(size) ? size : :md
      @align = ALIGN_CLASSES.key?(align) ? align : :left
    end

    def call
      content_tag(:div, class: "ui-stat #{ALIGN_CLASSES[@align]}") do
        safe_join([
          label_block,
          value_block,
          secondary_block,
          trend_block
        ].compact)
      end
    end

    private

    def label_block
      return nil if @label.blank?

      content_tag(:div, class: "ui-stat-label") do
        parts = []
        parts << content_tag(:i, "", class: @icon) if @icon.present?
        parts << content_tag(:span, @label)
        safe_join(parts)
      end
    end

    def value_block
      content_tag(
        :div,
        class: "ui-stat-value #{SIZE_CLASSES[@size]}"
      ) do
        parts = [ content_tag(:span, @value) ]
        parts << content_tag(:span, @unit, class: "ui-stat-unit") if @unit.present?
        safe_join(parts)
      end
    end

    def secondary_block
      return nil if @secondary.blank?

      content_tag(:p, @secondary, class: "ui-stat-secondary")
    end

    def trend_block
      return nil if @trend.blank?

      trend_key = @trend.to_sym
      spec = TREND_CLASSES[trend_key] || TREND_CLASSES[:flat]
      content_tag(:p, class: "ui-stat-trend #{spec[:color]}") do
        safe_join([
          content_tag(:i, "", class: "fa-regular #{spec[:icon]}"),
          " ",
          @trend_label.to_s
        ])
      end
    end
  end
end

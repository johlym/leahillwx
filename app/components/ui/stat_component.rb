# frozen_string_literal: true

# Big value + label + optional secondary line and trend indicator.
# Used for current-conditions tiles, records cards, and trends anomalies.
module Ui
  class StatComponent < ViewComponent::Base
    SIZES = %i[sm md lg xl].freeze
    TRENDS = { up: "fa-arrow-trend-up", down: "fa-arrow-trend-down", flat: "fa-minus" }.freeze

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
      @size = SIZES.include?(size) ? size : :md
      @align = %i[left center right].include?(align) ? align : :left
    end

    def call
      content_tag(:div, class: "ui-stat ui-stat--#{@size} ui-stat--align-#{@align}") do
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

      content_tag(:div, class: "ui-stat__label") do
        parts = []
        parts << content_tag(:i, "", class: "#{@icon} ui-stat__label-icon") if @icon.present?
        parts << content_tag(:span, @label, class: "ui-stat__label-text")
        safe_join(parts)
      end
    end

    def value_block
      content_tag(:div, class: "ui-stat__value") do
        parts = [ content_tag(:span, @value, class: "ui-stat__value-number") ]
        parts << content_tag(:span, @unit, class: "ui-stat__value-unit") if @unit.present?
        safe_join(parts)
      end
    end

    def secondary_block
      return nil if @secondary.blank?

      content_tag(:p, @secondary, class: "ui-stat__secondary")
    end

    def trend_block
      return nil if @trend.blank?

      trend_key = @trend.to_sym
      icon = TRENDS[trend_key] || TRENDS[:flat]
      content_tag(:p, class: "ui-stat__trend ui-stat__trend--#{trend_key}") do
        safe_join([
          content_tag(:i, "", class: "fa-regular #{icon}"),
          " ",
          @trend_label.to_s
        ])
      end
    end
  end
end

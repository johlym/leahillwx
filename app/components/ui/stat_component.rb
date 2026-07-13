# frozen_string_literal: true

# Big value + label + optional secondary line and trend indicator.
# Used for current-conditions tiles, records cards, and trends anomalies.
module Ui
  class StatComponent < ViewComponent::Base
    SIZE_CLASSES = {
      sm: "text-2xl",
      md: "text-4xl",
      lg: "text-5xl",
      xl: "text-7xl"
    }.freeze

    ALIGN_CLASSES = {
      left:   "items-start text-left",
      center: "items-center text-center",
      right:  "items-end text-right"
    }.freeze

    TREND_CLASSES = {
      up:   { icon: "fa-arrow-trend-up",   color: "text-success" },
      down: { icon: "fa-arrow-trend-down", color: "text-danger"  },
      flat: { icon: "fa-minus",            color: "text-muted"   }
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
      content_tag(:div, class: "flex flex-col gap-1 #{ALIGN_CLASSES[@align]}") do
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

      content_tag(:div, class: "inline-flex items-center gap-[0.4rem] text-xs uppercase tracking-[0.06em] text-muted") do
        parts = []
        parts << content_tag(:i, "", class: "#{@icon} text-accent") if @icon.present?
        parts << content_tag(:span, @label)
        safe_join(parts)
      end
    end

    def value_block
      content_tag(
        :div,
        class: "inline-flex items-baseline gap-[0.3rem] leading-none font-condensed font-medium text-text-strong tabular-nums #{SIZE_CLASSES[@size]}"
      ) do
        parts = [ content_tag(:span, @value) ]
        parts << content_tag(:span, @unit, class: "text-[0.55em] font-normal tracking-[0.02em] text-muted") if @unit.present?
        safe_join(parts)
      end
    end

    def secondary_block
      return nil if @secondary.blank?

      content_tag(:p, @secondary, class: "text-[0.8rem] text-muted")
    end

    def trend_block
      return nil if @trend.blank?

      trend_key = @trend.to_sym
      spec = TREND_CLASSES[trend_key] || TREND_CLASSES[:flat]
      content_tag(:p, class: "inline-flex items-center gap-1 text-xs #{spec[:color]}") do
        safe_join([
          content_tag(:i, "", class: "fa-regular #{spec[:icon]}"),
          " ",
          @trend_label.to_s
        ])
      end
    end
  end
end

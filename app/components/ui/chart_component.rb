# frozen_string_literal: true

# Wraps a Chart.js chart driven by `chart_controller.js`. Ruby is only
# responsible for shaping data and (light) options; palette-aware
# theming is applied client-side by reading the current CSS token layer.
#
#   render Ui::ChartComponent.new(
#     type: "line",
#     data: { labels: [...], datasets: [{ label: "High", key: "high", data: [...] }] },
#     options: { yUnit: "°F", stacked: false },
#     height: 360,
#     title: "Temperature",
#     aria_label: "Line chart of daily temperature"
#   )
module Ui
  class ChartComponent < ViewComponent::Base
    FIGURE_CLASSES = <<~CLASSES.gsub(/\s+/, " ").strip.freeze
      relative m-0 rounded-[0.85rem] border border-border-strong/55
      bg-linear-160 from-surface/94 to-surface-2/94 text-text
      backdrop-blur-sm backdrop-saturate-150 px-4 pt-4 pb-2
      shadow-[0_1px_0_color-mix(in_oklab,var(--color-text)_4%,transparent)_inset,0_12px_30px_-20px_rgba(0,0,0,0.7)]
    CLASSES

    def initialize(type:, data:, options: {}, height: 360, title: nil, subtitle: nil, aria_label: nil)
      @type = type.to_s
      @data = data
      @options = options
      @height = height
      @title = title
      @subtitle = subtitle
      @aria_label = aria_label
    end

    def call
      content_tag(:figure, class: FIGURE_CLASSES) do
        parts = []
        if @title.present? || @subtitle.present?
          parts << content_tag(:figcaption, class: "flex flex-col gap-[0.15rem] mb-3") do
            safe_join([
              @title.present?    ? content_tag(:span, @title,    class: "font-condensed uppercase tracking-[0.04em] text-[1.05rem] text-text-strong") : nil,
              @subtitle.present? ? content_tag(:span, @subtitle, class: "text-[0.8rem] text-muted") : nil
            ].compact)
          end
        end
        parts << chart_frame
        safe_join(parts.compact)
      end
    end

    private

    def chart_frame
      content_tag(
        :div,
        "",
        class: "ui-chart-frame h-(--chart-height)",
        style: "--chart-height: #{@height.to_i}px;",
        data: {
          controller: "chart",
          chart_type_value: @type,
          chart_data_value: @data.to_json,
          chart_options_value: @options.to_json
        },
        role: "img",
        "aria-label": @aria_label || @title
      )
    end
  end
end

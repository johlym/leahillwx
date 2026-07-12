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
      content_tag(:figure, class: "ui-chart") do
        parts = []
        if @title.present? || @subtitle.present?
          parts << content_tag(:figcaption, class: "ui-chart__caption") do
            safe_join([
              @title.present? ? content_tag(:span, @title, class: "ui-chart__title") : nil,
              @subtitle.present? ? content_tag(:span, @subtitle, class: "ui-chart__subtitle") : nil
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
        class: "ui-chart__frame",
        style: "height: #{@height.to_i}px;",
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

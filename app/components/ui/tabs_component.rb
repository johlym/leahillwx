# frozen_string_literal: true

# Segmented control for switching between named panels. Purely visual
# outside of an accompanying `data-controller` — pass a `controller` and
# `action` if you want click behavior wired up.
#
#   render Ui::TabsComponent.new(
#     current: :sun,
#     items: [
#       { id: :sun, label: "Sun", icon: "far fa-sun", action: "click->almanac-table-toggle#showSun" },
#       { id: :moon, label: "Moon", icon: "far fa-moon", action: "click->almanac-table-toggle#showMoon" }
#     ]
#   )
module Ui
  class TabsComponent < ViewComponent::Base
    def initialize(items:, current: nil, size: :md)
      @items = items
      @current = current
      @size = %i[sm md].include?(size) ? size : :md
    end

    def call
      root_class = [ "ui-tabs", (@size == :sm ? "ui-tabs-sm" : nil) ].compact.join(" ")
      content_tag(:div, class: root_class, role: "tablist") do
        safe_join(@items.map { |item| render_item(item) })
      end
    end

    private

    def render_item(item)
      active = active?(item)
      classes = [ "ui-tabs-tab", (active ? "ui-tabs-tab-active" : nil) ].compact.join(" ")
      content_tag(
        :button,
        button_content(item),
        type: "button",
        role: "tab",
        "aria-selected": active,
        class: classes,
        data: item[:data] || (item[:action] ? { action: item[:action] } : {})
      )
    end

    def button_content(item)
      parts = []
      parts << content_tag(:i, "", class: "#{item[:icon]} text-[0.85em]") if item[:icon].present?
      parts << content_tag(:span, item[:label])
      safe_join(parts, " ")
    end

    def active?(item)
      return false if @current.nil?
      item[:id].to_s == @current.to_s
    end
  end
end

# frozen_string_literal: true

# Consistent section header used to introduce a group of cards.
#
#   <%= render Ui::SectionHeaderComponent.new(title: "Records", subtitle: "All-time") do |s| %>
#     <% s.with_actions do %>
#       <%= render Ui::YearPickerComponent.new(...) %>
#     <% end %>
#   <% end %>
module Ui
  class SectionHeaderComponent < ViewComponent::Base
    renders_one :actions

    def initialize(title:, subtitle: nil, icon: nil, level: 2)
      @title = title
      @subtitle = subtitle
      @icon = icon
      @level = [ 1, 2, 3 ].include?(level) ? level : 2
    end

    def call
      content_tag(:div, class: "ui-section-header") do
        safe_join([
          title_block,
          actions? ? content_tag(:div, actions, class: "ui-section-header-actions") : nil
        ].compact)
      end
    end

    private

    def title_block
      content_tag(:div, class: "ui-section-header-text") do
        title_html = safe_join([
          @icon.present? ? content_tag(:i, "", class: @icon) : nil,
          @title
        ].compact, " ")

        safe_join([
          content_tag("h#{@level}", title_html, class: "ui-section-header-title"),
          @subtitle.present? ? content_tag(:p, @subtitle, class: "ui-section-header-subtitle") : nil
        ].compact)
      end
    end
  end
end

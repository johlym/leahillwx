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
          actions? ? content_tag(:div, actions, class: "flex items-center gap-3 shrink-0") : nil
        ].compact)
      end
    end

    private

    def title_block
      content_tag(:div, class: "min-w-0") do
        title_html = safe_join([
          @icon.present? ? content_tag(:i, "", class: "#{@icon} mr-[0.35rem] text-accent") : nil,
          @title
        ].compact, " ")

        safe_join([
          content_tag(
            "h#{@level}",
            title_html,
            class: "font-condensed uppercase tracking-[0.05em] text-text-strong text-[1.75rem] text-shadow-[0_0_24px_color-mix(in_oklab,var(--color-accent)_22%,transparent)]"
          ),
          @subtitle.present? ? content_tag(:p, @subtitle, class: "mt-[0.15rem] text-[0.85rem] text-muted") : nil
        ].compact)
      end
    end
  end
end

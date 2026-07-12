# frozen_string_literal: true

# Reusable year-pivot dropdown that navigates on change to
# `base_path[/:year]`. Optionally shows an "All time" option that maps
# to `base_path` (no year suffix).
module Ui
  class YearPickerComponent < ViewComponent::Base
    def initialize(base_path:, current_year:, years:, all_time_label: "All time", include_all_time: false, label: "Year")
      @base_path = base_path
      @current_year = current_year
      @years = Array(years).uniq.sort.reverse
      @all_time_label = all_time_label
      @include_all_time = include_all_time
      @label = label
    end

    def call
      content_tag(:label, class: "ui-year-picker") do
        safe_join([
          content_tag(:span, @label, class: "ui-year-picker__label"),
          select_element
        ])
      end
    end

    private

    def select_element
      content_tag(:select, class: "ui-year-picker__select", onchange: onchange_js) do
        safe_join(options_html)
      end
    end

    def options_html
      opts = []
      if @include_all_time
        opts << content_tag(:option, @all_time_label, value: @base_path, selected: @current_year.nil?)
      end
      @years.each do |year|
        opts << content_tag(:option, year.to_s, value: url_for_year(year), selected: @current_year.to_i == year.to_i)
      end
      opts
    end

    def url_for_year(year)
      "#{@base_path}/#{year}"
    end

    def onchange_js
      "if (this.value) { window.location.href = this.value; }"
    end
  end
end

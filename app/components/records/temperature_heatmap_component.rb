# frozen_string_literal: true

module Records
  class TemperatureHeatmapComponent < ViewComponent::Base
    def initialize(year:, days:)
      @year = year
      @days = days
    end

    private

    attr_reader :year, :days

    def call
      render Ui::CardComponent.new(padding: :default, classes: "temperature-heatmap-card") do
        content_tag(:p, "Temperature heatmap coming online — landing in a follow-up commit.", class: "text-[color:var(--muted)]")
      end
    end
  end
end

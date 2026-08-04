# frozen_string_literal: true

# GitHub-style calendar heatmap of daily high temperatures for a given
# year. 12 rows (one per month), up to 31 columns (one per day). Colors
# ramp sky -> emerald -> amber -> orange -> rose -> red as temperature
# climbs across the observed range (DESIGN.md semantic weather accents).
# Days marked as `partial: true` (incomplete data) get a diagonal-stripe
# overlay so a viewer can tell the value is provisional. Tooltip on each
# cell shows the date and the high/low pair via the shared tooltip controller.
module Records
  class TemperatureHeatmapComponent < ViewComponent::Base
    # 7-stop OKLCH ramp. The interpolation is done in oklab which
    # preserves perceptual smoothness across the hue rotation.
    COLOR_STOPS = [
      "oklch(0.45 0.12 245)",   # deep sky
      "oklch(0.58 0.14 220)",   # sky
      "oklch(0.68 0.14 180)",   # teal
      "oklch(0.75 0.15 145)",   # emerald
      "oklch(0.82 0.16 90)",    # amber
      "oklch(0.72 0.18 45)",    # orange
      "oklch(0.65 0.2 20)"      # rose/red
    ].freeze

    def initialize(year:, days:, highlight_month: nil)
      @year = year
      @days = days
      @highlight_month = highlight_month
    end

    def render?
      @days.present?
    end

    private

    attr_reader :year, :days, :highlight_month

    def highlighted?(month)
      highlight_month && month == highlight_month
    end

    # Group days by month for fast lookup while rendering rows.
    def days_by_month
      @days_by_month ||= days.group_by { |d| d[:month] }
    end

    def temp_domain
      @temp_domain ||= begin
        highs = days.map { |d| d[:high_f] }.compact
        if highs.empty?
          [ 0.0, 100.0 ]
        else
          lo = highs.min.floor.to_f
          hi = highs.max.ceil.to_f
          hi = lo + 1.0 if hi <= lo # avoid divide-by-zero on flat data
          [ lo, hi ]
        end
      end
    end

    def temp_min
      temp_domain[0]
    end

    def temp_max
      temp_domain[1]
    end

    def color_for(value)
      return nil if value.nil?
      t = ((value - temp_min) / (temp_max - temp_min)).clamp(0.0, 1.0)
      interpolate_color(t)
    end

    # Piecewise interpolation between adjacent COLOR_STOPS using
    # color-mix, which lets us stay in OKLCH end-to-end.
    def interpolate_color(t)
      segments = COLOR_STOPS.length - 1
      scaled = t * segments
      lower = scaled.floor.clamp(0, segments - 1)
      upper = lower + 1
      local = ((scaled - lower) * 100).round
      "color-mix(in oklab, #{COLOR_STOPS[upper]} #{local}%, #{COLOR_STOPS[lower]})"
    end

    def cell_style(day)
      color = color_for(day[:high_f])
      background = if day[:partial] && color
        # Diagonal-stripe overlay for partial days: the color fill lives
        # underneath and the pattern layer sits on top.
        "background-image: repeating-linear-gradient(45deg, transparent 0 4px, rgba(0,0,0,0.35) 4px 6px); background-color: #{color};"
      elsif color
        "background-color: #{color};"
      else
        ""
      end
      background
    end

    def cell_title(day)
      Date.new(year, day[:month], day[:day]).strftime("%b %d, %Y")
    end

    def cell_body(day)
      parts = []
      parts << "High #{day[:high_f].round}\u00B0F" if day[:high_f]
      parts << "Low #{day[:low_f].round}\u00B0F" if day[:low_f]
      parts << "(partial data)" if day[:partial]
      parts.join(" \u00B7 ")
    end

    def month_label(m)
      Date::ABBR_MONTHNAMES[m]
    end

    def day_ticks
      [ 1, 5, 10, 15, 20, 25, 31 ]
    end

    # CSS linear-gradient string that reproduces the full ramp used by
    # the cells. Each COLOR_STOPS entry is anchored at its evenly-spaced
    # position across 0-100%, so a viewer sees the same interpolation
    # in the legend as they do in the grid.
    def legend_gradient
      segments = COLOR_STOPS.length - 1
      stops = COLOR_STOPS.each_with_index.map do |color, i|
        pct = ((i.to_f / segments) * 100).round(2)
        "#{color} #{pct}%"
      end
      "linear-gradient(to right, #{stops.join(', ')})"
    end
  end
end

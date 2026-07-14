# frozen_string_literal: true

# Converts PM2.5 concentration (µg/m³) to EPA AQI using the standard
# piecewise-linear breakpoint formula, and maps AQI to category labels.
module EpaPm25Aqi
  extend ActiveSupport::Concern

  # [BPLo, BPHi, ILo, IHi]
  PM25_BREAKPOINTS = [
    [ 0.0, 12.0, 0, 50 ],
    [ 12.1, 35.4, 51, 100 ],
    [ 35.5, 55.4, 101, 150 ],
    [ 55.5, 150.4, 151, 200 ],
    [ 150.5, 250.4, 201, 300 ],
    [ 250.5, 350.4, 301, 400 ],
    [ 350.5, 500.4, 401, 500 ]
  ].freeze

  CATEGORIES = [
    [ 0, 50, "Good" ],
    [ 51, 100, "Moderate" ],
    [ 101, 150, "Unhealthy for Sensitive Groups" ],
    [ 151, 200, "Unhealthy" ],
    [ 201, 300, "Very Unhealthy" ],
    [ 301, nil, "Hazardous" ]
  ].freeze

  module ClassMethods
    def epa_aqi_from_pm25(concentration)
      return nil if concentration.nil?

      cp = concentration.to_f
      return 0 if cp <= 0

      PM25_BREAKPOINTS.each do |bp_lo, bp_hi, i_lo, i_hi|
        next if cp > bp_hi

        return (((i_hi - i_lo).to_f / (bp_hi - bp_lo)) * (cp - bp_lo) + i_lo).round
      end

      500
    end

    def epa_category_for(aqi)
      return nil if aqi.nil?

      value = aqi.to_i
      CATEGORIES.each do |lo, hi, label|
        return label if hi.nil? ? value >= lo : value.between?(lo, hi)
      end
      "Hazardous"
    end

    # Maps EPA AQI onto the live color bar (0–100%).
    # 0–100 → 0–⅓, 100–200 → ⅓–⅔, 200–500 → ⅔–100.
    def aqi_marker_position_for(aqi)
      return 0.0 if aqi.nil?

      value = aqi.to_f.clamp(0.0, 500.0)
      position =
        if value <= 100
          (value / 100.0) * (1.0 / 3.0)
        elsif value <= 200
          (1.0 / 3.0) + ((value - 100.0) / 100.0) * (1.0 / 3.0)
        else
          (2.0 / 3.0) + ((value - 200.0) / 300.0) * (1.0 / 3.0)
        end

      (position * 100.0).round(1)
    end
  end
end

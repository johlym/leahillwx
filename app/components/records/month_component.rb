# frozen_string_literal: true

# Renders a month-level view of the Records page. Values are derived
# from a single Report row + its entries; every card compares against
# the same month one year prior and shows a small delta indicator.
module Records
  class MonthComponent < ViewComponent::Base
    include UnitConversions
    include DateTimeFormatting

    def initialize(year:, month:, report:, prior_report:)
      @year = year
      @month = month
      @report = report
      @prior_report = prior_report
    end

    def render?
      @report.present?
    end

    def month_name
      Date::MONTHNAMES[@month]
    end

    def title
      "#{month_name} #{@year}"
    end

    def subtitle
      if @prior_report
        "Compared to #{month_name} #{@year - 1}"
      else
        "No data for #{month_name} #{@year - 1} to compare against."
      end
    end

    def cards
      [
        card(:mean_temp,   "Mean Temperature",  :temp,     "fa-regular fa-temperature-half",
             positive_label: "warmer",  negative_label: "cooler"),
        card(:high_temp,   "Highest Temperature", :temp,   "fa-regular fa-temperature-arrow-up",
             positive_label: "warmer",  negative_label: "cooler", day_field: :high_temp_day),
        card(:low_temp,    "Lowest Temperature",  :temp,   "fa-regular fa-temperature-arrow-down",
             positive_label: "warmer",  negative_label: "cooler", day_field: :low_temp_day),
        card(:total_rain,  "Total Rainfall",      :rain,   "fa-regular fa-cloud-showers-heavy",
             positive_label: "wetter",  negative_label: "drier"),
        card(:high_wind,   "Peak Wind",           :speed,  "fa-regular fa-wind",
             positive_label: "windier", negative_label: "calmer", day_field: :high_wind_day),
        card(:avg_wind,    "Average Wind",        :speed,  "fa-regular fa-wind",
             positive_label: "windier", negative_label: "calmer"),
        card(:heat_dd,     "Heating Degree Days", :number, "fa-regular fa-fire",
             positive_label: "colder",  negative_label: "warmer"),
        card(:cool_dd,     "Cooling Degree Days", :number, "fa-regular fa-icicles",
             positive_label: "warmer",  negative_label: "cooler")
      ]
    end

    private

    def card(key, label, type, icon, positive_label:, negative_label:, day_field: nil)
      current = extract(@report, key)
      previous = extract(@prior_report, key)
      day = extract_day(@report, key, day_field)

      formatted = format_value(current, type)
      delta = compute_delta(current, previous, type)

      {
        label: label,
        icon: icon,
        type: type,
        value: formatted[:value],
        unit: formatted[:unit],
        meta: card_meta(day, key),
        delta: delta,
        positive_label: positive_label,
        negative_label: negative_label
      }
    end

    def card_meta(day, key)
      return nil unless day
      case key
      when :high_temp then "on #{month_name} #{format('%02d', day)}"
      when :low_temp  then "on #{month_name} #{format('%02d', day)}"
      when :high_wind then "on #{month_name} #{format('%02d', day)}"
      end
    end

    def extract(report, key)
      return nil unless report
      case key
      when :mean_temp   then report.month_mean_temp
      when :high_temp   then report.month_high_temp
      when :low_temp    then report.month_low_temp
      when :total_rain  then report.total_rain
      when :high_wind   then report.month_high_wind_speed
      when :avg_wind    then report.avg_wind_speed
      when :heat_dd     then report.total_heat_degree_days
      when :cool_dd     then report.total_cool_degree_days
      end
    end

    def extract_day(report, key, day_field)
      return nil unless report && day_field
      case day_field
      when :high_temp_day then report.month_high_temp_day
      when :low_temp_day  then report.month_low_temp_day
      when :high_wind_day then report.month_high_wind_day
      end
    end

    def format_value(raw, type)
      return { value: "—", unit: nil } if raw.nil?

      case type
      when :temp
        { value: temp_fahrenheit(raw).round(1).to_s, unit: "°" }
      when :speed
        { value: wind_speed_mph(raw).round(1).to_s, unit: "mph" }
      when :rain
        { value: rain_in_inches(raw).round(2).to_s, unit: "in" }
      when :number
        { value: raw.round(1).to_s, unit: nil }
      else
        { value: raw.to_s, unit: nil }
      end
    end

    # Returns a hash { magnitude:, direction:, formatted: } or nil.
    # direction is :up, :down, or :flat (in the raw metric sense).
    def compute_delta(current, previous, type)
      return nil if current.nil? || previous.nil?
      diff = current - previous
      return { magnitude: 0, direction: :flat, formatted: "no change" } if diff.abs < epsilon(type)

      converted = case type
      when :temp  then diff * 9.0 / 5.0
      when :speed then diff * 2.23694
      when :rain  then diff / 25.4
      else diff
      end
      unit = case type
      when :temp  then "°"
      when :speed then " mph"
      when :rain  then " in"
      else ""
      end

      sign = converted.positive? ? "+" : ""
      formatted_val = "#{sign}#{converted.round(precision_for(type))}#{unit}"

      {
        magnitude: converted.abs,
        direction: converted.positive? ? :up : :down,
        formatted: formatted_val
      }
    end

    def epsilon(type)
      case type
      when :temp  then 0.05
      when :speed then 0.05
      when :rain  then 0.01
      else 0.05
      end
    end

    def precision_for(type)
      case type
      when :rain then 2
      else 1
      end
    end
  end
end

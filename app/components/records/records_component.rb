# frozen_string_literal: true

module Records
  class RecordsComponent < ViewComponent::Base
    def initialize(pivot:, selected_year:, selected_year_record:, all_time_record:, available_years:, heatmap_year:, heatmap_days:, yearly_records: [], selected_month: nil, report: nil, prior_report: nil, available_report_months_by_year: {})
      @pivot = pivot
      @selected_year = selected_year
      @selected_month = selected_month
      @selected_year_record = selected_year_record
      @all_time_record = all_time_record
      @available_years = available_years
      @heatmap_year = heatmap_year
      @heatmap_days = heatmap_days
      @yearly_records = yearly_records
      @report = report
      @prior_report = prior_report
      @available_report_months_by_year = available_report_months_by_year
    end

    private

    attr_reader :pivot, :selected_year, :selected_month, :selected_year_record, :all_time_record,
                :available_years, :heatmap_year, :heatmap_days, :yearly_records,
                :report, :prior_report, :available_report_months_by_year

    def pivot_year?
      pivot == :year
    end

    def pivot_month?
      pivot == :month
    end

    def active_record
      pivot_year? ? selected_year_record : all_time_record
    end

    def pivot_title
      case pivot
      when :month
        "#{Date::MONTHNAMES[selected_month]} #{selected_year} Records"
      when :year
        "#{selected_year} Records"
      else
        "All-Time Records"
      end
    end

    def pivot_subtitle
      case pivot
      when :month
        "Extremes from the month plus a comparison against #{selected_year - 1}."
      when :year
        "Every recorded extreme for the #{selected_year} season."
      else
        "Every recorded extreme since the station came online."
      end
    end

    # Returns months available for the selected year, or the most recent
    # year with data if none is selected. Used to populate the month
    # picker in the header.
    def months_available_for_pivot
      year = selected_year || available_report_months_by_year.keys.max
      return [] unless year
      (available_report_months_by_year[year] || []).sort
    end

    def sections
      [
        { title: "Temperature", icon: "fa-regular fa-temperature-half", rows: temperature_rows },
        { title: "Wind",        icon: "fa-regular fa-wind",             rows: wind_rows },
        { title: "Rain",        icon: "fa-regular fa-cloud-rain",       rows: rain_rows },
        { title: "Humidity",    icon: "fa-regular fa-hand-holding-droplet", rows: humidity_rows },
        { title: "Barometer",   icon: "fa-regular fa-gauge",            rows: barometer_rows },
        { title: "Sun",         icon: "fa-regular fa-sun",              rows: sun_rows }
      ]
    end

    def temperature_rows
      [
        { label: "Highest Temperature", field: :highest_temp, type: :temp, timestamp_field: :highest_temp_at, timestamp_type: :datetime, icon: "fa-regular fa-temperature-arrow-up" },
        { label: "Lowest Temperature", field: :lowest_temp, type: :temp, timestamp_field: :lowest_temp_at, timestamp_type: :datetime, icon: "fa-regular fa-temperature-arrow-down" },
        { label: "Highest Apparent Temperature", field: :highest_apparent_temp, type: :temp, timestamp_field: :highest_apparent_temp_at, timestamp_type: :datetime, icon: "fa-regular fa-sun" },
        { label: "Lowest Apparent Temperature", field: :lowest_apparent_temp, type: :temp, timestamp_field: :lowest_apparent_temp_at, timestamp_type: :datetime, icon: "fa-regular fa-snowflake" },
        { label: "Highest Heat Index", field: :highest_heat_index, type: :temp, timestamp_field: :highest_heat_index_at, timestamp_type: :datetime, icon: "fa-regular fa-fire" },
        { label: "Lowest Wind Chill", field: :lowest_wind_chill, type: :temp, timestamp_field: :lowest_wind_chill_at, timestamp_type: :datetime, icon: "fa-regular fa-icicles" },
        { label: "Largest Daily Temperature Range", field: :largest_temp_range, type: :temp, timestamp_field: :largest_temp_range_date, timestamp_type: :date, icon: "fa-regular fa-arrows-up-down" },
        { label: "Smallest Daily Temperature Range", field: :smallest_temp_range, type: :temp, timestamp_field: :smallest_temp_range_date, timestamp_type: :date, icon: "fa-regular fa-grip-lines" }
      ]
    end

    def wind_rows
      [
        { label: "Strongest Gust", field: :strongest_gust, type: :speed, timestamp_field: :strongest_gust_at, timestamp_type: :datetime, icon: "fa-regular fa-wind" },
        { label: "Highest Daily Wind Run", field: :highest_wind_run, type: :wind_run, timestamp_field: :highest_wind_run_date, timestamp_type: :date, icon: "fa-regular fa-route" }
      ]
    end

    def rain_rows
      [
        { label: "Highest Daily Rainfall", field: :highest_daily_rain, type: :rain, timestamp_field: :highest_daily_rain_date, timestamp_type: :date, icon: "fa-regular fa-cloud-showers-heavy" },
        { label: "Highest Daily Rain Rate", field: :highest_rain_rate, type: :rain, timestamp_field: :highest_rain_rate_at, timestamp_type: :datetime, icon: "fa-regular fa-cloud-bolt" },
        { label: "Wettest Month", field: :wettest_month, type: :month, year_field: :wettest_month_year, timestamp_field: :wettest_month_total, timestamp_type: :rain, icon: "fa-regular fa-calendar-week" },
        { label: "Longest Rainy Streak", field: :consecutive_rain_days, type: :days, timestamp_field: :consecutive_rain_start_date, timestamp_type: :date, icon: "fa-regular fa-umbrella" },
        { label: "Longest Dry Streak", field: :consecutive_dry_days, type: :days, timestamp_field: :consecutive_dry_start_date, timestamp_type: :date, icon: "fa-regular fa-sun-cloud" }
      ]
    end

    def humidity_rows
      [
        { label: "Highest Humidity", field: :highest_humidity, type: :humidity, timestamp_field: :highest_humidity_at, timestamp_type: :datetime, icon: "fa-regular fa-droplet" },
        { label: "Lowest Humidity", field: :lowest_humidity, type: :humidity, timestamp_field: :lowest_humidity_at, timestamp_type: :datetime, icon: "fa-regular fa-droplet-slash" },
        { label: "Highest Dew Point", field: :highest_dew_point, type: :temp, timestamp_field: :highest_dew_point_at, timestamp_type: :datetime, icon: "fa-regular fa-droplet-degree" },
        { label: "Lowest Dew Point", field: :lowest_dew_point, type: :temp, timestamp_field: :lowest_dew_point_at, timestamp_type: :datetime, icon: "fa-regular fa-droplet-degree" }
      ]
    end

    def barometer_rows
      [
        { label: "Highest Pressure", field: :highest_pressure, type: :pressure, timestamp_field: :highest_pressure_at, timestamp_type: :datetime, icon: "fa-regular fa-arrow-up" },
        { label: "Lowest Pressure", field: :lowest_pressure, type: :pressure, timestamp_field: :lowest_pressure_at, timestamp_type: :datetime, icon: "fa-regular fa-arrow-down" },
        { label: "Largest Daily Pressure Swing", field: :largest_pressure_swing, type: :pressure, timestamp_field: :largest_pressure_swing_date, timestamp_type: :date, icon: "fa-regular fa-arrows-up-down" }
      ]
    end

    def sun_rows
      [
        { label: "Highest Solar Irradiance", field: :highest_solar, type: :solar, timestamp_field: :highest_solar_at, timestamp_type: :datetime, icon: "fa-regular fa-sun-bright" }
      ]
    end
  end
end

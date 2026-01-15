# frozen_string_literal: true

module Records
  class RecordsComponent < ViewComponent::Base
    def initialize(selected_year_record:, current_year_record:, all_time_record:, selected_year:, current_year:)
      @selected_year_record = selected_year_record
      @current_year_record = current_year_record
      @all_time_record = all_time_record
      @selected_year = selected_year
      @current_year = current_year
    end

    private

    attr_reader :selected_year_record, :current_year_record, :all_time_record, :selected_year, :current_year

    def show_three_columns?
      @selected_year != @current_year
    end

    def year_record
      show_three_columns? ? selected_year_record : current_year_record
    end

    def year_label
      if show_three_columns?
        selected_year.to_s
      else
        selected_year == current_year ? "#{selected_year} (Jan 1 - yesterday)" : selected_year.to_s
      end
    end

    def current_year_label
      "#{current_year} (Jan 1 - yesterday)"
    end

    def temperature_rows
      [
        { label: "Highest Temperature", field: :highest_temp, type: :temp, timestamp_field: :highest_temp_at, timestamp_type: :datetime },
        { label: "Lowest Temperature", field: :lowest_temp, type: :temp, timestamp_field: :lowest_temp_at, timestamp_type: :datetime },
        { label: "Highest Apparent Temperature", field: :highest_apparent_temp, type: :temp, timestamp_field: :highest_apparent_temp_at, timestamp_type: :datetime },
        { label: "Lowest Apparent Temperature", field: :lowest_apparent_temp, type: :temp, timestamp_field: :lowest_apparent_temp_at, timestamp_type: :datetime },
        { label: "Highest Heat Index", field: :highest_heat_index, type: :temp, timestamp_field: :highest_heat_index_at, timestamp_type: :datetime },
        { label: "Lowest Wind Chill", field: :lowest_wind_chill, type: :temp, timestamp_field: :lowest_wind_chill_at, timestamp_type: :datetime },
        { label: "Largest Daily Temperature Range", field: :largest_temp_range, type: :temp, timestamp_field: :largest_temp_range_date, timestamp_type: :date },
        { label: "Smallest Daily Temperature Range", field: :smallest_temp_range, type: :temp, timestamp_field: :smallest_temp_range_date, timestamp_type: :date }
      ]
    end

    def wind_rows
      [
        { label: "Strongest Gust", field: :strongest_gust, type: :speed, timestamp_field: :strongest_gust_at, timestamp_type: :datetime },
        { label: "Highest Daily Wind Run", field: :highest_wind_run, type: :wind_run, timestamp_field: :highest_wind_run_date, timestamp_type: :date }
      ]
    end

    def rain_rows
      [
        { label: "Highest Daily Rainfall", field: :highest_daily_rain, type: :rain, timestamp_field: :highest_daily_rain_date, timestamp_type: :date },
        { label: "Highest Daily Rain Rate", field: :highest_rain_rate, type: :rain, timestamp_field: :highest_rain_rate_at, timestamp_type: :datetime },
        { label: "Month with Most Rain", field: :wettest_month, type: :month, year_field: :wettest_month_year, timestamp_field: :wettest_month_total, timestamp_type: :rain },
        { label: "Consecutive Days with Rain", field: :consecutive_rain_days, type: :days, timestamp_field: :consecutive_rain_start_date, timestamp_type: :date },
        { label: "Consecutive Days without Rain", field: :consecutive_dry_days, type: :days, timestamp_field: :consecutive_dry_start_date, timestamp_type: :date }
      ]
    end

    def humidity_rows
      [
        { label: "Highest Humidity", field: :highest_humidity, type: :humidity, timestamp_field: :highest_humidity_at, timestamp_type: :datetime },
        { label: "Lowest Humidity", field: :lowest_humidity, type: :humidity, timestamp_field: :lowest_humidity_at, timestamp_type: :datetime },
        { label: "Highest Dew Point", field: :highest_dew_point, type: :temp, timestamp_field: :highest_dew_point_at, timestamp_type: :datetime },
        { label: "Lowest Dew Point", field: :lowest_dew_point, type: :temp, timestamp_field: :lowest_dew_point_at, timestamp_type: :datetime }
      ]
    end

    def barometer_rows
      [
        { label: "Highest Pressure", field: :highest_pressure, type: :pressure, timestamp_field: :highest_pressure_at, timestamp_type: :datetime },
        { label: "Lowest Pressure", field: :lowest_pressure, type: :pressure, timestamp_field: :lowest_pressure_at, timestamp_type: :datetime },
        { label: "Largest Pressure Swing (Day)", field: :largest_pressure_swing, type: :pressure, timestamp_field: :largest_pressure_swing_date, timestamp_type: :date }
      ]
    end

    def sun_rows
      [
        { label: "Highest Solar Irradiance", field: :highest_solar, type: :solar, timestamp_field: :highest_solar_at, timestamp_type: :datetime }
      ]
    end
  end
end

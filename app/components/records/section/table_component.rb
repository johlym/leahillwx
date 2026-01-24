# frozen_string_literal: true

module Records
  module Section
    class TableComponent < ViewComponent::Base
      include UnitConversions
      include DateTimeFormatting

      def initialize(rows:, year_label:, current_year_label:, show_three_columns:)
        @rows = rows
        @year_label = year_label
        @current_year_label = current_year_label
        @show_three_columns = show_three_columns
      end

      private

      attr_reader :rows, :year_label, :current_year_label, :show_three_columns

      def show_three_columns?
        @show_three_columns
      end

      def format_temp(celsius)
        return "N/A" unless celsius
        "#{temp_fahrenheit(celsius).round(1)}°F"
      end

      def format_speed(mps)
        return "N/A" unless mps
        "#{wind_speed_mph(mps).round(1)} mph"
      end

      def format_rain(mm)
        return "N/A" unless mm
        "#{rain_in_inches(mm).round(2)} in"
      end

      def format_pressure(hpa)
        return "N/A" unless hpa
        "#{hpa.round(2)} hPa"
      end

      def format_solar(wm2)
        return "N/A" unless wm2
        "#{wm2.round(1)} W/m²"
      end

      def format_month(month_num, year)
        return "N/A" unless month_num && year
        "#{Date::MONTHNAMES[month_num]} #{year}"
      end

      def format_wind_run(miles)
        return "N/A" unless miles
        "#{miles.round(1)} miles"
      end

      def format_hours(hours)
        return "N/A" unless hours
        "#{hours} hours"
      end

      def format_days(days)
        return "N/A" unless days
        "#{days} days"
      end

      def format_humidity(humidity)
        return "N/A" unless humidity
        "#{humidity}%"
      end

      def format_value(row, record)
        return "N/A" unless record

        case row[:type]
        when :temp
          format_temp(record.public_send(row[:field]))
        when :speed
          format_speed(record.public_send(row[:field]))
        when :rain
          format_rain(record.public_send(row[:field]))
        when :pressure
          format_pressure(record.public_send(row[:field]))
        when :solar
          format_solar(record.public_send(row[:field]))
        when :wind_run
          format_wind_run(record.public_send(row[:field]))
        when :hours
          format_hours(record.public_send(row[:field]))
        when :days
          format_days(record.public_send(row[:field]))
        when :humidity
          format_humidity(record.public_send(row[:field]))
        when :month
          format_month(record.public_send(row[:field]), record.public_send(row[:year_field]))
        end
      end

      def format_timestamp(row, record)
        return "N/A" unless record

        value = record.public_send(row[:timestamp_field])
        case row[:timestamp_type]
        when :datetime
          format_datetime(value)
        when :date
          format_date(value)
        when :rain
          format_rain(value)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Graphs
  class ChartBuilder
    def initialize(year:, month:, day: nil)
      @year = year
      @month = month
      @day = day
    end

    def temperature_chart
      entries = entries
      return nil if entries.blank?

      labels = entries.map { |e| entry_label(e) }
      highs = entries.map { |e| e.high_temp ? c_to_f(e.high_temp) : nil }
      lows = entries.map { |e| e.low_temp ? c_to_f(e.low_temp) : nil }
      means = entries.map { |e| e.mean_temp ? c_to_f(e.mean_temp) : nil }

      {
        type: "line",
        data: {
          labels: labels,
          datasets: [
            {
              label: "High",
              data: highs.map { |v| v&.round(1) },
              color: "var(--chart-2)",
              borderWidth: 2,
              tension: 0.3
            },
            {
              label: "Low",
              data: lows.map { |v| v&.round(1) },
              color: "var(--chart-1)",
              borderWidth: 2,
              tension: 0.3,
              fillTarget: 0
            },
            {
              label: "Mean",
              data: means.map { |v| v&.round(1) },
              color: "var(--chart-3)",
              borderWidth: 2,
              dashed: true,
              tension: 0.3
            }
          ]
        },
        options: {
          yUnit: "°F",
          yLabel: "Temperature (°F)",
          decimals: 1
        }
      }
    end

    def rain_chart
      entries = entries
      return nil if entries.blank? || entries.none? { |e| e.rain.present? }

      labels = entries.map { |e| entry_label(e) }
      rain = entries.map { |e| e.rain ? (e.rain / 25.4).round(3) : 0 }

      {
        type: "bar",
        data: {
          labels: labels,
          datasets: [
            {
              label: "Rain",
              data: rain,
              color: "var(--chart-6)",
              fill: true
            }
          ]
        },
        options: {
          yUnit: " in",
          yLabel: "Rainfall (in)",
          decimals: 2,
          hideLegend: true
        }
      }
    end

    def wind_chart
      entries = entries
      return nil if entries.blank? || entries.none? { |e| e.avg_wind_speed.present? || e.high_wind_speed.present? }

      labels = entries.map { |e| entry_label(e) }
      avg = entries.map { |e| e.avg_wind_speed ? (e.avg_wind_speed * 2.23694).round(1) : nil }
      high = entries.map { |e| e.high_wind_speed ? (e.high_wind_speed * 2.23694).round(1) : nil }

      {
        type: "line",
        data: {
          labels: labels,
          datasets: [
            {
              label: "Peak",
              data: high,
              color: "var(--chart-2)",
              tension: 0.25
            },
            {
              label: "Average",
              data: avg,
              color: "var(--chart-3)",
              tension: 0.25
            }
          ]
        },
        options: {
          yUnit: " mph",
          yLabel: "Wind speed (mph)",
          decimals: 1
        }
      }
    end

    private

    def entries
      @entries ||= begin
        report = Report.includes(:entries).find_by(year: @year, month: @month)
        return [] unless report

        scope = @day ? report.entries.hourly.where(day: @day) : report.entries.daily
        scope.ordered.with_data.to_a
      end
    end

    def entry_label(entry)
      entry.hourly? ? format("%02d:00", entry.hour) : entry.day.to_s
    end

    def c_to_f(celsius)
      (celsius * 9.0 / 5.0) + 32
    end
  end
end

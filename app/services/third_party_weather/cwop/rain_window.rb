# frozen_string_literal: true

module ThirdPartyWeather
  class Cwop
    # Sum rain across a sliding window using the daily rain counter.
    # Handles midnight resets (counter drops) by treating the new value as
    # post-reset accumulation. Uses the reading at/before window start as baseline
    # and prorates the first segment so pre-window rain is excluded.
    class RainWindow
      def self.inches(since:, through:)
        new(since: since, through: through).inches
      end

      def initialize(since:, through:)
        @since = since
        @through = through
      end

      def inches
        baseline = WeatherMeasurement
          .where(reading_date_time: ..@since)
          .order(reading_date_time: :desc)
          .limit(1)
          .pick(:reading_date_time, :rain_day)

        in_window = WeatherMeasurement
          .where(reading_date_time: @since..@through.reading_date_time)
          .order(:reading_date_time)
          .pluck(:reading_date_time, :rain_day)

        return 0.0 if in_window.empty?

        series = []
        series << baseline if baseline
        in_window.each do |row|
          series << row unless series.last == row
        end

        return 0.0 if series.size < 2

        total_mm = 0.0
        series.each_cons(2).with_index do |((t0, rain0), (t1, rain1)), index|
          delta = rain_day_delta_mm(t0, rain0, t1, rain1)

          if index.zero? && baseline && t0 < @since && t1 > @since
            span = (t1 - t0).to_f
            delta *= ((t1 - @since).to_f / span).clamp(0.0, 1.0) if span.positive?
          end

          total_mm += delta
        end

        total_mm / 25.4
      end

      private

      # Only treat a rain_day drop as a midnight reset when local date changes.
      # Same-day decreases are ignored as sensor glitches/corrections.
      def rain_day_delta_mm(t0, rain0, t1, rain1)
        return rain1 - rain0 if rain1 >= rain0
        return rain1 if crossed_local_midnight?(t0, t1)

        0.0
      end

      def crossed_local_midnight?(t0, t1)
        t0.in_time_zone.to_date != t1.in_time_zone.to_date
      end
    end
  end
end

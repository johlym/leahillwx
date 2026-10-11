# frozen_string_literal: true

module WeatherData
  # rain_day is the station's running total since local midnight, in millimeters.
  # It climbs as rain falls and drops when the station resets or replaces a bad
  # reading. The homepage tile shows that counter, so report totals follow the
  # counter at the end of the period rather than the highest reading seen.
  #
  # Using the maximum counts a spike, or yesterday's total still sitting on the
  # first packets after midnight, as if it were rain that stayed on the ground.
  # max - min on an hour has the same problem: one dip to zero turns the whole
  # daily total into that hour's rain.
  class RainTotal
    ZONE = "America/Los_Angeles"
    EPS = 1e-4

    Result = Struct.new(:hourly_mm, :total_mm, keyword_init: true)

    def self.attribute(measurements, baseline: nil)
      new(measurements, baseline: baseline).attribute
    end

    def initialize(measurements, baseline: nil)
      @measurements = measurements
      @baseline = baseline
    end

    def attribute
      ordered = @measurements.sort_by(&:reading_date_time)
      return Result.new(hourly_mm: {}, total_mm: 0.0) if ordered.empty?

      Result.new(
        hourly_mm: hourly_amounts(ordered),
        total_mm: ordered.last.rain_day.to_f
      )
    end

    private

    def hourly_amounts(ordered)
      amounts = Hash.new(0.0)
      accepted = 0.0
      pending_carryover = opening_carryover(ordered)

      if pending_carryover.nil? && same_day_baseline?(ordered.first)
        accepted = @baseline.rain_day.to_f
      end

      ordered.each do |measurement|
        rain = measurement.rain_day.to_f
        hour = measurement.reading_date_time.in_time_zone(ZONE).hour

        if pending_carryover && rain >= pending_carryover - EPS
          if rain > pending_carryover + EPS
            delta = rain - pending_carryover
            amounts[hour] += delta
            accepted += delta
            pending_carryover = rain
          end
          next
        end

        pending_carryover = nil

        if rain + EPS >= accepted
          delta = rain - accepted
          amounts[hour] += delta if delta > EPS
          accepted = rain
        else
          claw_back(amounts, hour, accepted - rain)
          accepted = rain
        end
      end

      amounts
    end

    # Yesterday's closing counter is still on the first packets of a new day
    # until the station resets. Those readings are not rain that fell today.
    # A baseline from earlier the same day is already part of today's counter.
    def opening_carryover(ordered)
      return if @baseline.nil?
      return if same_day_baseline?(ordered.first)

      @baseline.rain_day.to_f
    end

    def same_day_baseline?(measurement)
      return false unless @baseline

      @baseline.reading_date_time.in_time_zone(ZONE).to_date ==
        measurement.reading_date_time.in_time_zone(ZONE).to_date
    end

    def claw_back(amounts, hour, leftover)
      hour.downto(0) do |earlier|
        break if leftover <= EPS

        take = [ amounts[earlier], leftover ].min
        amounts[earlier] = (amounts[earlier] - take).clamp(0.0, Float::INFINITY)
        leftover -= take
      end
    end
  end
end

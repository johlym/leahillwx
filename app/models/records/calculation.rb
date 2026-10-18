module Records
  class Calculation
    CALCULATORS = [
      Records::TemperatureExtremes,
      Records::WindExtremes,
      Records::RainExtremes,
      Records::HumidityExtremes,
      Records::BarometerExtremes,
      Records::SolarExtremes
    ].freeze

    # Values sourced from weather_measurements. After PurgeOldWeatherMeasurementsJob
    # deletes rows older than MEASUREMENT_RETENTION_DAYS, a full all-time recalc
    # would otherwise overwrite the records table — the documented long-term store.
    MEASUREMENT_HIGHS = [
      [ :highest_temp, :highest_temp_at ],
      [ :highest_apparent_temp, :highest_apparent_temp_at ],
      [ :highest_heat_index, :highest_heat_index_at ],
      [ :highest_humidity, :highest_humidity_at ],
      [ :highest_dew_point, :highest_dew_point_at ],
      [ :highest_pressure, :highest_pressure_at ],
      [ :highest_rain_rate, :highest_rain_rate_at ],
      [ :highest_solar, :highest_solar_at ],
      [ :strongest_gust, :strongest_gust_at ],
      [ :highest_wind_run, :highest_wind_run_date ],
      [ :largest_pressure_swing, :largest_pressure_swing_date ]
    ].freeze

    MEASUREMENT_LOWS = [
      [ :lowest_temp, :lowest_temp_at ],
      [ :lowest_apparent_temp, :lowest_apparent_temp_at ],
      [ :lowest_wind_chill, :lowest_wind_chill_at ],
      [ :lowest_humidity, :lowest_humidity_at ],
      [ :lowest_dew_point, :lowest_dew_point_at ],
      [ :lowest_pressure, :lowest_pressure_at ]
    ].freeze

    def initialize(scope:, year: nil)
      @scope = scope
      @year = year
      @record = Record.find_or_initialize_by(scope: scope, year: year)
    end

    def calculate_and_save!
      previous = snapshot_measurement_extremes(@record)
      measurements = Records::MeasurementScope.new(scope: @scope, year: @year).resolve

      Rails.logger.info "Starting record calculation for #{@scope} #{@year || 'all-time'}"

      CALCULATORS.each do |calculator_class|
        calculator_class.new(record: @record, measurements: measurements, scope: @scope, year: @year).calculate
        Rails.logger.info "✓ #{calculator_class.name.demodulize.titleize} calculated"
      end

      preserve_all_time_measurement_extremes!(previous) if all_time_scope?

      @record.save!
      Rails.logger.info "✓ Record saved successfully"
      @record
    end

    private

    def all_time_scope?
      @scope.to_s == "all_time"
    end

    def preserve_all_time_measurement_extremes!(previous)
      snapshots = [ previous, snapshot_measurement_extremes(@record) ]
      Record.yearly.find_each { |yearly| snapshots << snapshot_measurement_extremes(yearly) }

      apply_extreme_envelope!(snapshots, MEASUREMENT_HIGHS, :max)
      apply_extreme_envelope!(snapshots, MEASUREMENT_LOWS, :min)
    end

    def snapshot_measurement_extremes(record)
      (MEASUREMENT_HIGHS + MEASUREMENT_LOWS).each_with_object({}) do |(value_attr, at_attr), hash|
        hash[value_attr] = record.public_send(value_attr)
        hash[at_attr] = record.public_send(at_attr)
      end
    end

    def apply_extreme_envelope!(snapshots, pairs, direction)
      pairs.each do |value_attr, at_attr|
        best = nil

        snapshots.each do |snapshot|
          value = snapshot[value_attr]
          next if value.nil?

          if best.nil? || more_extreme?(value, best[:value], direction)
            best = { value: value, at: snapshot[at_attr] }
          end
        end

        next unless best

        @record.public_send(:"#{value_attr}=", best[:value])
        @record.public_send(:"#{at_attr}=", best[:at])
      end
    end

    def more_extreme?(value, incumbent, direction)
      direction == :max ? value > incumbent : value < incumbent
    end
  end
end

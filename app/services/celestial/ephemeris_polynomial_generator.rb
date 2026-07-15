module Celestial
  class EphemerisPolynomialGenerator
    TIMEZONE = "America/Los_Angeles"
    MAX_ERROR = 0.01  # Maximum allowed error in degrees
    MIN_SEGMENT_DURATION = 60  # Minimum segment duration in seconds (1 minute)
    SAMPLE_INTERVAL = 30  # Sample every 30 seconds for fitting

    def initialize
      @ephem_generator = Almanac::EphemGenerator.new
      @bsp_positions = @ephem_generator.bsp_positions
      @horizon_events = @ephem_generator.horizon_events
    end

    def generate_daily_ephemeris(body, year, month, day)
      date = Date.new(year, month, day)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      day_start = tz.parse("#{date} 00:00:00")

      midnight_timestamp = day_start.to_i

      events = generate_events(body, day_start)

      observables = {
        "alt" => generate_altitude_segments(body, day_start),
        "az" => generate_azimuth_segments(body, day_start)
      }

      {
        t: midnight_timestamp,
        m: 86400,
        e: events,
        o: {
          body.to_s => observables
        }
      }
    end

    private

    def generate_events(body, day_start)
      day_end = day_start + 1.day
      events = []

      case body
      when :sun
        if sunrise = @horizon_events.sun_rise(day_start, day_end)
          events << { s: (sunrise - day_start).to_i, t: 1 }
        end

        if sunset = @horizon_events.sun_set(day_start, day_end)
          events << { s: (sunset - day_start).to_i, t: 2 }
        end

        if transit = @horizon_events.sun_transit(day_start, day_end)
          events << { s: (transit - day_start).to_i, t: 3 }
        end

      when :moon
        if moonrise = @horizon_events.moon_rise(day_start, day_end)
          events << { s: (moonrise - day_start).to_i, t: 1 }
        end

        if moonset = @horizon_events.moon_set(day_start, day_end)
          events << { s: (moonset - day_start).to_i, t: 2 }
        end

        if transit = @horizon_events.moon_transit(day_start, day_end)
          events << { s: (transit - day_start).to_i, t: 3 }
        end
      end

      events.sort_by! { |e| e[:s] }

      { body.to_s => events }
    end

    def generate_altitude_segments(body, day_start)
      samples = sample_observable(body, day_start, :altitude)
      fit_polynomial_segments(samples, 0, 86400)
    end

    def generate_azimuth_segments(body, day_start)
      samples = sample_observable(body, day_start, :azimuth)
      unwrapped_samples = unwrap_azimuth(samples)
      fit_polynomial_segments(unwrapped_samples, 0, 86400)
    end

    def sample_observable(body, day_start, observable)
      samples = []

      (0..86400).step(SAMPLE_INTERVAL) do |seconds|
        time = day_start + seconds
        jd = @ephem_generator.datetime_to_julian_date(time)
        position = @bsp_positions.position_for(body, jd)
        samples << { t: seconds, v: position[observable] }
      end

      samples
    end

    def unwrap_azimuth(samples)
      return samples if samples.empty?

      unwrapped = [samples[0]]
      offset = 0.0

      samples.each_cons(2) do |prev, curr|
        delta = curr[:v] - prev[:v]

        if delta > 180.0
          offset -= 360.0
        elsif delta < -180.0
          offset += 360.0
        end

        unwrapped << { t: curr[:t], v: curr[:v] + offset }
      end

      unwrapped
    end

    def fit_polynomial_segments(samples, start_time, end_time)
      segments = []
      current_start = start_time
      i = 0

      while i < samples.length && current_start < end_time
        segment_start_idx = i

        best_segment = nil
        best_end_idx = i

        j = i + 1
        while j <= samples.length
          segment_end = j < samples.length ? samples[j][:t] : end_time

          if segment_end - current_start > 3600
            break if best_segment
          end

          segment_samples = samples[segment_start_idx...j].select { |s| s[:t] >= current_start }

          next if segment_samples.empty?

          coeffs = fit_cubic_polynomial(segment_samples, current_start)
          max_error = compute_max_error(segment_samples, coeffs, current_start)

          if max_error <= MAX_ERROR
            best_segment = {
              e: segment_end,
              p: coeffs.map { |c| c.round(8) }
            }
            best_end_idx = j
            j += 1
          else
            break
          end
        end

        if best_segment.nil?
          next_sample_time = samples[i + 1]&.dig(:t) || end_time
          segment_end = [next_sample_time, current_start + MIN_SEGMENT_DURATION, end_time].min
          segment_samples = samples.select { |s| s[:t] >= current_start && s[:t] <= segment_end }

          if segment_samples.empty?
            segment_samples = [{ t: current_start, v: samples[i][:v] }]
          end

          coeffs = fit_cubic_polynomial(segment_samples, current_start)
          best_segment = {
            e: segment_end,
            p: coeffs.map { |c| c.round(8) }
          }
          i += 1
        else
          i = best_end_idx
        end

        segments << best_segment
        current_start = best_segment[:e]
      end

      if segments.any? && segments.last[:e] != end_time
        segments.last[:e] = end_time
      end

      segments
    end

    def fit_cubic_polynomial(samples, t0)
      return [0.0, 0.0, 0.0, 0.0] if samples.empty?

      if samples.length <= 2
        return fit_linear_polynomial(samples, t0) + [0.0, 0.0]
      end

      a_matrix = Array.new(4) { Array.new(4, 0.0) }
      b_vector = Array.new(4, 0.0)

      samples.each do |sample|
        dt = sample[:t] - t0
        v = sample[:v]

        dt_powers = [1.0, dt, dt**2, dt**3]

        4.times do |i|
          b_vector[i] += v * dt_powers[i]
          4.times do |j|
            a_matrix[i][j] += dt_powers[i] * dt_powers[j]
          end
        end
      end

      solve_linear_system(a_matrix, b_vector)
    end

    def fit_linear_polynomial(samples, t0)
      return [samples[0][:v], 0.0] if samples.length == 1

      sum_dt = 0.0
      sum_v = 0.0
      sum_dt_v = 0.0
      sum_dt2 = 0.0

      samples.each do |sample|
        dt = sample[:t] - t0
        v = sample[:v]
        sum_dt += dt
        sum_v += v
        sum_dt_v += dt * v
        sum_dt2 += dt**2
      end

      n = samples.length.to_f
      denominator = n * sum_dt2 - sum_dt**2

      if denominator.abs < 1e-10
        return [sum_v / n, 0.0]
      end

      a1 = (n * sum_dt_v - sum_dt * sum_v) / denominator
      a0 = (sum_v - a1 * sum_dt) / n

      [a0, a1]
    end

    def solve_linear_system(a_matrix, b_vector)
      n = a_matrix.length

      a = a_matrix.map(&:dup)
      b = b_vector.dup

      (n - 1).times do |k|
        max_row = k
        (k + 1...n).each do |i|
          max_row = i if a[i][k].abs > a[max_row][k].abs
        end

        if max_row != k
          a[k], a[max_row] = a[max_row], a[k]
          b[k], b[max_row] = b[max_row], b[k]
        end

        (k + 1...n).each do |i|
          next if a[k][k].abs < 1e-10

          factor = a[i][k] / a[k][k]
          (k...n).each do |j|
            a[i][j] -= factor * a[k][j]
          end
          b[i] -= factor * b[k]
        end
      end

      x = Array.new(n, 0.0)
      (n - 1).downto(0) do |i|
        if a[i][i].abs < 1e-10
          x[i] = 0.0
          next
        end

        sum = 0.0
        (i + 1...n).each do |j|
          sum += a[i][j] * x[j]
        end
        x[i] = (b[i] - sum) / a[i][i]
      end

      x
    end

    def compute_max_error(samples, coeffs, t0)
      max_error = 0.0

      samples.each do |sample|
        dt = sample[:t] - t0
        predicted = coeffs[0] + coeffs[1] * dt + coeffs[2] * dt**2 + coeffs[3] * dt**3
        error = (predicted - sample[:v]).abs
        max_error = [max_error, error].max
      end

      max_error
    end
  end
end

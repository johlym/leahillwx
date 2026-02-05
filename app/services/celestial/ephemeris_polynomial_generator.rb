module Celestial
  class EphemerisPolynomialGenerator
    TIMEZONE = "America/Los_Angeles"
    MAX_ERROR = 0.01  # Maximum allowed error in degrees
    MIN_SEGMENT_DURATION = 60  # Minimum segment duration in seconds (1 minute)
    SAMPLE_INTERVAL = 30  # Sample every 30 seconds for fitting

    def initialize
      @ephem_generator = Almanac::EphemGenerator.new
    end

    def generate_daily_ephemeris(body, year, month, day)
      # Parse date and get local timezone boundaries
      date = Date.new(year, month, day)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      day_start = tz.parse("#{date} 00:00:00")

      # Unix timestamp of local midnight
      midnight_timestamp = day_start.to_i

      # Generate events
      events = generate_events(body, day_start)

      # Generate polynomial observables
      observables = {
        "alt" => generate_altitude_segments(body, day_start),
        "az" => generate_azimuth_segments(body, day_start)
      }

      # Build response according to spec
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
        # Event type codes (opaque to consumer)
        # 1 = rise, 2 = set, 3 = upper transit, 4 = lower transit

        if sunrise = @ephem_generator.send(:sun_rise_set_local, day_start, day_end)
          events << { s: (sunrise - day_start).to_i, t: 1 }
        end

        if sunset = @ephem_generator.send(:sun_set_local, day_start, day_end)
          events << { s: (sunset - day_start).to_i, t: 2 }
        end

        if transit = @ephem_generator.send(:sun_transit_local, day_start, day_end)
          events << { s: (transit - day_start).to_i, t: 3 }
        end

      when :moon
        # Event type codes: 1 = rise, 2 = set, 3 = upper transit

        if moonrise = @ephem_generator.send(:moon_rise_local, day_start, day_end)
          events << { s: (moonrise - day_start).to_i, t: 1 }
        end

        if moonset = @ephem_generator.send(:moon_set_local, day_start, day_end)
          events << { s: (moonset - day_start).to_i, t: 2 }
        end

        if transit = @ephem_generator.send(:moon_transit_local, day_start, day_end)
          events << { s: (transit - day_start).to_i, t: 3 }
        end
      end

      # Sort events by time
      events.sort_by! { |e| e[:s] }

      # Return events grouped by body
      { body.to_s => events }
    end

    def generate_altitude_segments(body, day_start)
      # Sample altitude throughout the day
      samples = sample_observable(body, day_start, :altitude)

      # Generate piecewise cubic segments
      fit_polynomial_segments(samples, 0, 86400)
    end

    def generate_azimuth_segments(body, day_start)
      # Sample azimuth throughout the day and unwrap it
      samples = sample_observable(body, day_start, :azimuth)
      unwrapped_samples = unwrap_azimuth(samples)

      # Generate piecewise cubic segments
      fit_polynomial_segments(unwrapped_samples, 0, 86400)
    end

    def sample_observable(body, day_start, observable)
      # Sample every SAMPLE_INTERVAL seconds
      samples = []

      (0..86400).step(SAMPLE_INTERVAL) do |seconds|
        time = day_start + seconds
        jd = @ephem_generator.send(:datetime_to_julian_date, time)

        position = if body == :sun
          @ephem_generator.send(:calculate_sun_position_bsp, jd)
        else
          @ephem_generator.send(:calculate_moon_position_bsp, jd)
        end

        samples << { t: seconds, v: position[observable] }
      end

      samples
    end

    def unwrap_azimuth(samples)
      # Unwrap azimuth to be continuous (can exceed ±360°)
      return samples if samples.empty?

      unwrapped = [ samples[0] ]
      offset = 0.0

      samples.each_cons(2) do |prev, curr|
        delta = curr[:v] - prev[:v]

        # Detect discontinuity (crossing 0°/360° boundary)
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
        # Find samples for this segment starting at current_start
        segment_start_idx = i

        # Try to fit progressively larger segments until error exceeds threshold
        best_segment = nil
        best_end_idx = i

        j = i + 1
        while j <= samples.length
          # Determine segment end
          segment_end = j < samples.length ? samples[j][:t] : end_time

          # Don't make segments too long
          if segment_end - current_start > 3600  # Max 1 hour segments
            break if best_segment
          end

          # Extract segment samples within current range
          segment_samples = samples[segment_start_idx...j].select { |s| s[:t] >= current_start }

          next if segment_samples.empty?

          # Fit cubic polynomial
          coeffs = fit_cubic_polynomial(segment_samples, current_start)

          # Validate fit
          max_error = compute_max_error(segment_samples, coeffs, current_start)

          if max_error <= MAX_ERROR
            best_segment = {
              e: segment_end,
              p: coeffs.map { |c| c.round(8) }
            }
            best_end_idx = j
            j += 1
          else
            # Error too large, use previous best segment
            break
          end
        end

        # If no valid segment found, create minimal segment
        if best_segment.nil?
          next_sample_time = samples[i + 1]&.dig(:t) || end_time
          segment_end = [ next_sample_time, current_start + MIN_SEGMENT_DURATION, end_time ].min
          segment_samples = samples.select { |s| s[:t] >= current_start && s[:t] <= segment_end }

          if segment_samples.empty?
            segment_samples = [ { t: current_start, v: samples[i][:v] } ]
          end

          coeffs = fit_cubic_polynomial(segment_samples, current_start)
          best_segment = {
            e: segment_end,
            p: coeffs.map { |c| c.round(8) }
          }
          i += 1
        else
          # Advance to continue from best segment end
          i = best_end_idx
        end

        segments << best_segment
        current_start = best_segment[:e]
      end

      # Ensure final segment ends exactly at end_time
      if segments.any? && segments.last[:e] != end_time
        segments.last[:e] = end_time
      end

      segments
    end

    def fit_cubic_polynomial(samples, t0)
      # Fit a cubic polynomial: v(t) = a0 + a1*dt + a2*dt^2 + a3*dt^3
      # where dt = t - t0

      return [ 0.0, 0.0, 0.0, 0.0 ] if samples.empty?

      # If only one or two points, fit lower order polynomial
      if samples.length <= 2
        return fit_linear_polynomial(samples, t0) + [ 0.0, 0.0 ]
      end

      # Build matrices for least squares fit
      a_matrix = Array.new(4) { Array.new(4, 0.0) }
      b_vector = Array.new(4, 0.0)

      samples.each do |sample|
        dt = sample[:t] - t0
        v = sample[:v]

        dt_powers = [ 1.0, dt, dt**2, dt**3 ]

        4.times do |i|
          b_vector[i] += v * dt_powers[i]
          4.times do |j|
            a_matrix[i][j] += dt_powers[i] * dt_powers[j]
          end
        end
      end

      # Solve the system using Gaussian elimination
      solve_linear_system(a_matrix, b_vector)
    end

    def fit_linear_polynomial(samples, t0)
      # Fit v(t) = a0 + a1*dt
      return [ samples[0][:v], 0.0 ] if samples.length == 1

      # Simple linear regression
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
        # Degenerate case, return constant
        return [ sum_v / n, 0.0 ]
      end

      a1 = (n * sum_dt_v - sum_dt * sum_v) / denominator
      a0 = (sum_v - a1 * sum_dt) / n

      [ a0, a1 ]
    end

    def solve_linear_system(a_matrix, b_vector)
      # Gaussian elimination with partial pivoting
      n = a_matrix.length

      # Make copies to avoid modifying originals
      a = a_matrix.map(&:dup)
      b = b_vector.dup

      # Forward elimination
      (n - 1).times do |k|
        # Partial pivoting
        max_row = k
        (k + 1...n).each do |i|
          max_row = i if a[i][k].abs > a[max_row][k].abs
        end

        if max_row != k
          a[k], a[max_row] = a[max_row], a[k]
          b[k], b[max_row] = b[max_row], b[k]
        end

        # Elimination
        (k + 1...n).each do |i|
          next if a[k][k].abs < 1e-10

          factor = a[i][k] / a[k][k]
          (k...n).each do |j|
            a[i][j] -= factor * a[k][j]
          end
          b[i] -= factor * b[k]
        end
      end

      # Back substitution
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
      # Compute maximum absolute error between polynomial and samples
      max_error = 0.0

      samples.each do |sample|
        dt = sample[:t] - t0
        predicted = coeffs[0] + coeffs[1] * dt + coeffs[2] * dt**2 + coeffs[3] * dt**3
        error = (predicted - sample[:v]).abs
        max_error = [ max_error, error ].max
      end

      max_error
    end
  end
end

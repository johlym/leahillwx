module WindVectorAveraging
  extend ActiveSupport::Concern

  module ClassMethods
    def calculate_dominant_wind_direction(measurements)
      return nil if measurements.empty?

      u_sum = 0.0
      v_sum = 0.0

      measurements.each do |m|
        wind_speed = m.wind_speed
        wind_dir = m.wind_dir

        next if wind_speed.nil? || wind_dir.nil?
        next if wind_speed < 0.5

        theta_rad = wind_dir * Math::PI / 180.0
        u_sum += wind_speed * Math.sin(theta_rad)
        v_sum += wind_speed * Math.cos(theta_rad)
      end

      return nil if u_sum.zero? && v_sum.zero?

      angle_rad = Math.atan2(u_sum, v_sum)
      angle_deg = angle_rad * 180.0 / Math::PI
      angle_deg += 360.0 if angle_deg < 0

      angle_deg.round
    end
  end

  def degrees_to_compass(degrees)
    return nil if degrees.nil?

    directions = %w[N NE E SE S SW W NW]
    index = ((degrees + 22.5) / 45.0).floor % 8
    directions[index]
  end
end

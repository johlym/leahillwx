module HeadingToCompass
  extend ActiveSupport::Concern

  included do
    # nothing needed here yet
  end

  COMPASS_DIRECTIONS_8 = %w[
    N NE E SE S SW W NW
  ].freeze

  def heading_to_compass
    return nil if wind_dir.blank?

    degrees = wind_dir.to_f % 360
    index = ((degrees / 45.0).round) % 8

    COMPASS_DIRECTIONS_8[index]
  end
end

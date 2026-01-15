class AlmanacPosition < ApplicationRecord
  validates :date, presence: true
  validates :hour, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 23 }
  validates :date, uniqueness: { scope: :hour }

  scope :ordered, -> { order(:date, :hour) }
  scope :for_date, ->(date) { where(date: date).ordered }
  scope :for_datetime, ->(datetime) { find_by(date: datetime.to_date, hour: datetime.hour) }

  def self.for_date_range(start_date, end_date)
    where(date: start_date..end_date).ordered
  end

  def formatted_sun_position
    return "N/A" unless sun_azimuth_deg && sun_altitude_deg
    "Az: #{sun_azimuth_deg.round(1)}°, Alt: #{sun_altitude_deg.round(1)}°"
  end

  def formatted_moon_position
    return "N/A" unless moon_azimuth_deg && moon_altitude_deg
    "Az: #{moon_azimuth_deg.round(1)}°, Alt: #{moon_altitude_deg.round(1)}°"
  end
end

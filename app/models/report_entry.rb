class ReportEntry < ApplicationRecord
  include WeatherUnitConversions

  belongs_to :report

  validates :day, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }
  validates :day, uniqueness: { scope: :report_id }
  validates :partial_day, inclusion: { in: [ true, false ] }

  scope :ordered, -> { order(:day) }
  scope :with_data, -> { where.not(mean_temp: nil) }

  def has_data?
    mean_temp.present? || high_temp.present? || low_temp.present?
  end

  def formatted_temp(temp)
    return "N/A" if temp.nil?
    temp_f = celsius_to_fahrenheit(temp)
    format("%.2f", temp_f)
  end

  def formatted_time(time)
    return "N/A" if time.nil?
    time
  end

  def formatted_rain
    return "N/A" if rain.nil?
    format("%.2f", rain)
  end

  def formatted_wind_speed(speed)
    return "N/A" if speed.nil?
    format("%.2f", speed)
  end

  def formatted_degree_days(dd)
    return "N/A" if dd.nil?
    format("%.2f", dd)
  end

  def formatted_wind_dir
    return "N/A" if wind_dir.nil?
    "#{wind_dir} (#{wind_dir_compass})"
  end
end

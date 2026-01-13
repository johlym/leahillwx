class Report < ApplicationRecord
  include WindVectorAveraging
  include WeatherUnitConversions

  has_many :entries, class_name: "ReportEntry", dependent: :destroy

  validates :year, presence: true, numericality: { only_integer: true, greater_than: 2000 }
  validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :year, uniqueness: { scope: :month }

  scope :by_year, ->(year) { where(year: year) }
  scope :ordered, -> { order(year: :desc, month: :desc) }

  def self.find_by_month_name(year, month_name)
    month_num = Date::MONTHNAMES.index(month_name.capitalize)
    return nil unless month_num

    find_by(year: year, month: month_num)
  end

  def self.available_years_and_months
    all.order(year: :desc, month: :desc)
       .pluck(:year, :month)
       .group_by(&:first)
       .transform_values { |months| months.map(&:last).sort }
  end

  def month_name
    Date::MONTHNAMES[month]
  end

  def month_name_short
    Date::ABBR_MONTHNAMES[month]
  end

  def display_name
    "#{month_name} #{year}"
  end

  def days_in_month
    Date.new(year, month, -1).day
  end

  def formatted_dominant_wind
    return "N/A" if dominant_wind_dir.nil?
    "#{dominant_wind_dir} (#{dominant_wind_dir_compass})"
  end

  def formatted_temp(temp)
    return "N/A" if temp.nil?
    format("%.2f", temp)
  end

  def formatted_degree_days(dd)
    return "N/A" if dd.nil?
    format("%.2f", dd)
  end

  def formatted_rain(rain_val)
    return "N/A" if rain_val.nil?
    format("%.2f", rain_val)
  end

  def formatted_wind_speed(speed)
    return "N/A" if speed.nil?
    format("%.2f", speed)
  end
end

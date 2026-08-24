# == Schema Information
#
# Table name: reports
#
#  id                        :bigint           not null, primary key
#  avg_wind_speed            :float
#  dominant_wind_dir         :integer
#  dominant_wind_dir_compass :string
#  month                     :integer          not null
#  month_high_pressure       :float
#  month_high_pressure_day   :integer
#  month_high_temp           :float
#  month_high_temp_day       :integer
#  month_high_wind_day       :integer
#  month_high_wind_speed     :float
#  month_low_pressure        :float
#  month_low_pressure_day    :integer
#  month_low_temp            :float
#  month_low_temp_day        :integer
#  month_mean_pressure       :float
#  month_mean_temp           :float
#  total_cool_degree_days    :float
#  total_heat_degree_days    :float
#  total_rain                :float
#  year                      :integer          not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_reports_on_year_and_month  (year,month) UNIQUE
#
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

  def formatted_rain(rain_mm)
    return "N/A" if rain_mm.nil?
    format("%.2f", rain_mm / 25.4)
  end

  def formatted_wind_speed(speed_mps)
    return "N/A" if speed_mps.nil?
    format("%.2f", speed_mps * 2.23694)
  end

  def formatted_pressure(pressure_hpa)
    return "N/A" if pressure_hpa.nil?
    format("%.1f", pressure_hpa)
  end
end

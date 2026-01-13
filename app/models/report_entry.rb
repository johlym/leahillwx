# == Schema Information
#
# Table name: report_entries
#
#  id               :bigint           not null, primary key
#  avg_wind_speed   :float
#  cool_degree_days :float
#  day              :integer          not null
#  heat_degree_days :float
#  high_temp        :float
#  high_temp_time   :string
#  high_wind_speed  :float
#  high_wind_time   :string
#  low_temp         :float
#  low_temp_time    :string
#  mean_temp        :float
#  partial_day      :boolean          default(FALSE), not null
#  rain             :float
#  wind_dir         :integer
#  wind_dir_compass :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  report_id        :bigint           not null
#
# Indexes
#
#  index_report_entries_on_report_id          (report_id)
#  index_report_entries_on_report_id_and_day  (report_id,day) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (report_id => reports.id) ON DELETE => cascade
#
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

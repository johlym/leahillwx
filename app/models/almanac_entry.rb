# == Schema Information
#
# Table name: almanac_entries
#
#  id                     :bigint           not null, primary key
#  civil_dawn_at          :datetime
#  civil_dusk_at          :datetime
#  date                   :date             not null
#  daylight_delta_seconds :integer
#  daylight_seconds       :integer
#  moon_illumination_pct  :float
#  moon_phase             :string
#  moon_transit_at        :datetime
#  moonrise_at            :datetime
#  moonset_at             :datetime
#  next_equinox_at        :datetime
#  next_full_moon_at      :datetime
#  next_new_moon_at       :datetime
#  next_solstice_at       :datetime
#  solar_noon_at          :datetime
#  sunrise_at             :datetime
#  sunset_at              :datetime
#  timezone               :string           default("America/Los_Angeles"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_almanac_entries_on_date  (date) UNIQUE
#
class AlmanacEntry < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :timezone, presence: true

  scope :ordered, -> { order(date: :desc) }
  scope :for_date, ->(date) { find_by(date: date) }

  def self.for_date_range(start_date, end_date)
    where(date: start_date..end_date).ordered
  end

  def self.available_years
    distinct.pluck(Arel.sql("EXTRACT(YEAR FROM date)")).map(&:to_i).sort.reverse
  end

  def self.available_dates_by_year
    all.order(date: :desc)
       .pluck(:date)
       .group_by(&:year)
       .transform_values { |dates| dates.map { |d| { month: d.month, day: d.day } } }
  end

  def formatted_daylight
    return "N/A" unless daylight_seconds

    hours = daylight_seconds / 3600
    minutes = (daylight_seconds % 3600) / 60
    seconds = daylight_seconds % 60

    "#{hours} hours, #{minutes} minutes, #{seconds} seconds"
  end

  def formatted_daylight_delta
    return nil unless daylight_delta_seconds

    abs_seconds = daylight_delta_seconds.abs
    minutes = abs_seconds / 60
    seconds = abs_seconds % 60

    sign = daylight_delta_seconds.positive? ? "more" : "less"
    "#{minutes} minute#{'s' if minutes != 1}, #{seconds} second#{'s' if seconds != 1} #{sign} than yesterday"
  end
end

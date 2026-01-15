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

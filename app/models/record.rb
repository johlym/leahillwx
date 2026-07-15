# == Schema Information
#
# Table name: records
#
#  id                          :bigint           not null, primary key
#  consecutive_dry_days        :integer
#  consecutive_dry_start_date  :date
#  consecutive_rain_days       :integer
#  consecutive_rain_start_date :date
#  highest_apparent_temp       :float
#  highest_apparent_temp_at    :datetime
#  highest_daily_rain          :float
#  highest_daily_rain_date     :date
#  highest_dew_point           :float
#  highest_dew_point_at        :datetime
#  highest_heat_index          :float
#  highest_heat_index_at       :datetime
#  highest_humidity            :integer
#  highest_humidity_at         :datetime
#  highest_pressure            :float
#  highest_pressure_at         :datetime
#  highest_rain_rate           :float
#  highest_rain_rate_at        :datetime
#  highest_solar               :float
#  highest_solar_at            :datetime
#  highest_temp                :float
#  highest_temp_at             :datetime
#  highest_wind_run            :float
#  highest_wind_run_date       :date
#  largest_pressure_swing      :float
#  largest_pressure_swing_date :date
#  largest_temp_range          :float
#  largest_temp_range_date     :date
#  longest_calm_hours          :integer
#  longest_calm_start_at       :datetime
#  lowest_apparent_temp        :float
#  lowest_apparent_temp_at     :datetime
#  lowest_dew_point            :float
#  lowest_dew_point_at         :datetime
#  lowest_humidity             :integer
#  lowest_humidity_at          :datetime
#  lowest_pressure             :float
#  lowest_pressure_at          :datetime
#  lowest_temp                 :float
#  lowest_temp_at              :datetime
#  lowest_wind_chill           :float
#  lowest_wind_chill_at        :datetime
#  scope                       :string           not null
#  smallest_temp_range         :float
#  smallest_temp_range_date    :date
#  strongest_gust              :float
#  strongest_gust_at           :datetime
#  wettest_month               :integer
#  wettest_month_total         :float
#  wettest_month_year          :integer
#  year                        :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_records_on_scope_and_year  (scope,year) UNIQUE
#
class Record < ApplicationRecord
  enum :scope, { yearly: "yearly", all_time: "all_time" }

  validates :scope, presence: true
  validates :year, presence: true, if: -> { yearly? }
  validates :year, absence: true, if: -> { all_time? }
  validates :scope, uniqueness: { scope: :year }

  scope :for_year, ->(year) { where(scope: "yearly", year: year) }

  def self.all_time_record
    find_by(scope: "all_time")
  end

  def self.current_year_record
    for_year(Time.current.year).first
  end

  def display_year_range
    return "All Time" if all_time?

    if year == Time.current.year
      "#{year} (Jan 1 - present)"
    else
      year.to_s
    end
  end
end

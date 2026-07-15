# == Schema Information
#
# Table name: aqis
#
#  id          :bigint           not null, primary key
#  co          :float
#  epa_aqi     :integer
#  nh3         :float
#  no          :float
#  no2         :float
#  o3          :float
#  observed_at :datetime         not null
#  pm10        :float
#  pm2_5       :float            not null
#  so2         :float
#  source      :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_aqis_on_observed_at  (observed_at) UNIQUE
#  index_aqis_on_source       (source)
#
class Aqi < ApplicationRecord
  include EpaPm25Aqi
  extend EpaPm25Aqi::ClassMethods

  SOURCES = %w[openweather airnow].freeze
  STALE_AFTER = 8.hours

  validates :pm2_5, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :observed_at, presence: true, uniqueness: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :epa_aqi, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :co, :nh3, :no, :no2, :o3, :pm10, :so2,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :with_observation, -> { where.not(observed_at: nil) }
  scope :chronological, -> { order(observed_at: :asc) }

  def self.latest
    with_observation.order(observed_at: :desc).first
  end

  def self.recent(hours: 48)
    cutoff = hours.hours.ago
    with_observation.where("observed_at >= ?", cutoff).chronological
  end

  # Daily mean PM2.5 and EPA AQI for charting.
  # Days are bucketed in America/Los_Angeles.
  # When epa_aqi is missing for a day, derive it from the day's mean PM2.5.
  def self.daily_averages(from:, to:, zone: "America/Los_Angeles")
    rows = with_observation
      .where(observed_at: from..to)
      .pluck(:observed_at, :pm2_5, :epa_aqi)

    rows
      .group_by { |observed_at, _, _| observed_at.in_time_zone(zone).to_date }
      .sort_by(&:first)
      .map do |date, day_rows|
        pm_values = day_rows.map { |_, pm, _| pm }.compact
        aqi_values = day_rows.map { |_, _, aqi| aqi }.compact
        pm2_5 = pm_values.any? ? (pm_values.sum / pm_values.size.to_f).round(2) : nil
        epa_aqi =
          if aqi_values.any?
            (aqi_values.sum / aqi_values.size.to_f).round(1)
          elsif pm2_5
            epa_aqi_from_pm25(pm2_5)&.to_f
          end
        {
          date: date,
          pm2_5: pm2_5,
          epa_aqi: epa_aqi
        }
      end
  end

  # Upsert one hourly reading. AirNow rows are never overwritten by OpenWeather.
  def self.upsert_reading!(observed_at:, pm2_5:, source:, epa_aqi: nil, **components)
    raise ArgumentError, "source must be one of #{SOURCES.join(', ')}" unless SOURCES.include?(source.to_s)

    observed_at = observed_at.utc.change(min: 0, sec: 0) if observed_at.respond_to?(:utc)
    epa_aqi = epa_aqi_from_pm25(pm2_5) if epa_aqi.blank? && pm2_5.present?

    attrs = {
      pm2_5: pm2_5,
      epa_aqi: epa_aqi,
      source: source.to_s,
      observed_at: observed_at
    }.merge(components.compact)

    existing = find_by(observed_at: observed_at)
    if existing
      return existing if existing.source == "airnow" && source.to_s == "openweather"

      existing.update!(attrs)
      return existing
    end

    create!(attrs)
  end

  def stale?(hours: 8)
    return true if observed_at.blank?

    observed_at < hours.hours.ago
  end

  def epa_category
    self.class.epa_category_for(epa_aqi.presence || self.class.epa_aqi_from_pm25(pm2_5))
  end

  def resolved_epa_aqi
    epa_aqi.presence || self.class.epa_aqi_from_pm25(pm2_5)
  end

  # 0..100 for the color bar. Piecewise (log-esque) layout:
  # 0–100 → first third, 100–200 → middle third, 200–500 → last third.
  def aqi_marker_position
    self.class.aqi_marker_position_for(resolved_epa_aqi)
  end
end

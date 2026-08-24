# frozen_string_literal: true

# == Schema Information
#
# Table name: planet_nights
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  planets    :jsonb            not null
#  timezone   :string           default("America/Los_Angeles"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_planet_nights_on_date  (date) UNIQUE
#
class PlanetNight < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :planets, presence: true

  def self.for_date(date)
    find_by(date: date)
  end

  def visible_planets
    Array(planets).select do |planet|
      planet["visible_tonight"] && rise_on_card_date?(planet)
    end
  end

  private

  def rise_on_card_date?(planet)
    rise = planet["rise_at"]
    return true if rise.blank?

    Time.zone.parse(rise).in_time_zone(timezone).to_date <= date
  rescue ArgumentError, TypeError
    true
  end
end

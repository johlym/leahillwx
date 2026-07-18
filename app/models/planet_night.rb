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
class PlanetNight < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :planets, presence: true

  def self.for_date(date)
    find_by(date: date)
  end

  def visible_planets
    Array(planets).select { |p| p["visible_tonight"] }
  end
end

# frozen_string_literal: true

class GeneratePlanetNightJob
  include Sidekiq::Job

  def perform(date_iso = nil)
    date = date_iso ? Date.iso8601(date_iso) : Time.zone.today
    Almanac::PlanetNightGenerator.new.generate_and_persist!(date)
  end
end

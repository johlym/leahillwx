# frozen_string_literal: true

# Reduce station (absolute) pressure to sea-level / altimeter setting.
#
# Nearby METAR and NWS stations report this value. The console "relative"
# field is an uncalibrated offset and is slightly *below* station pressure
# here, so it cannot be used as sea-level pressure.
#
# Uses the NWS ASOS altimeter formula (P and A in inHg, H in feet):
#   A = (P_s^0.190284 + 1.313e-5 * H)^5.2553026
class SeaLevelPressure
  HPA_PER_INHG = 33.8638866667
  DEFAULT_ELEVATION_FT = 416.0
  EXPONENT = 0.190284
  INVERSE_EXPONENT = 5.2553026
  ELEVATION_COEFFICIENT = 1.313e-5

  def self.elevation_ft
    ENV.fetch("LOCATION_ELEVATION_FT", DEFAULT_ELEVATION_FT.to_s).to_f
  end

  def self.hpa(station_hpa, elevation_ft: self.elevation_ft)
    return if station_hpa.nil?

    station = station_hpa.to_f
    return station if station <= 0 || elevation_ft.to_f.zero?

    inhg(station / HPA_PER_INHG, elevation_ft: elevation_ft) * HPA_PER_INHG
  end

  def self.inhg(station_inhg, elevation_ft: self.elevation_ft)
    return if station_inhg.nil?

    station = station_inhg.to_f
    return station if station <= 0 || elevation_ft.to_f.zero?

    ((station**EXPONENT) + (ELEVATION_COEFFICIENT * elevation_ft.to_f))**INVERSE_EXPONENT
  end
end

# frozen_string_literal: true

# Reduce station (absolute) pressure to sea level.
#
# The console "relative" field is an uncalibrated offset and is slightly
# *below* station pressure here, so it cannot be used as sea-level pressure.
# AWEKAS QC flagged that gap at about -18.5 hPa (they received ~1000 vs
# expected ~1018.5).
#
# Two reductions:
# - hpa / inhg: NWS ASOS altimeter (QNH). METAR and CWOP.
#     A = (P_s^0.190284 + 1.313e-5 * H)^5.2553026  (inHg, feet)
# - qff_hpa: weewx/wview sea-level (QFF), uses actual temperature.
#     P_msl = P_s / exp(-h / (T_K * 29.263))
#   AWEKAS documents QFF.
class SeaLevelPressure
  HPA_PER_INHG = 33.8638866667
  DEFAULT_ELEVATION_FT = 416.0
  EXPONENT = 0.190284
  INVERSE_EXPONENT = 5.2553026
  ELEVATION_COEFFICIENT = 1.313e-5
  FEET_TO_METERS = 0.3048
  QFF_SCALE = 29.263

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

  def self.qff_hpa(station_hpa, temp_c:, elevation_ft: self.elevation_ft)
    return if station_hpa.nil? || temp_c.nil?

    station = station_hpa.to_f
    height_m = elevation_ft.to_f * FEET_TO_METERS
    return station if station <= 0 || height_m.zero?

    term = Math.exp(-height_m / ((temp_c.to_f + 273.15) * QFF_SCALE))
    return 0 if term.zero?

    station / term
  end
end

module FeelsLike
  extend ActiveSupport::Concern

  def feels_like_c(temp_c:, humidity:, wind_speed_mps:, cloud_pct:, is_daytime:)
    if cold_enough_for_wind_chill?(temp_c, wind_speed_mps)
      wind_chill_c(temp_c, wind_speed_mps)
    elsif hot_enough_for_heat_index?(temp_c, humidity)
      heat_index_c(temp_c, humidity)
    else
      apparent_temperature_c(temp_c, humidity, wind_speed_mps, cloud_pct, is_daytime)
    end
  end

  # --------------------
  # Wind Chill
  # --------------------
  def cold_enough_for_wind_chill?(temp_c, wind_speed_mps)
    temp_c <= 10.0 && wind_speed_mps >= 1.3
  end

  def wind_chill_c(temp_c, wind_speed_mps)
    wind_kmh = wind_speed_mps * 3.6

    wc =
      13.12 +
      0.6215 * temp_c -
      11.37 * wind_kmh**0.16 +
      0.3965 * temp_c * wind_kmh**0.16

    [ wc, temp_c ].min
  end

  # --------------------
  # Heat Index
  # --------------------
  def hot_enough_for_heat_index?(temp_c, humidity)
    temp_c >= 27.0 && humidity >= 40
  end

  def heat_index_c(temp_c, humidity)
    temp_f = c_to_f(temp_c)
    rh = humidity

    hi_f =
      -42.379 +
      2.04901523 * temp_f +
      10.14333127 * rh -
      0.22475541 * temp_f * rh -
      0.00683783 * temp_f**2 -
      0.05481717 * rh**2 +
      0.00122874 * temp_f**2 * rh +
      0.00085282 * temp_f * rh**2 -
      0.00000199 * temp_f**2 * rh**2

    hi_c = f_to_c(hi_f)
    [ hi_c, temp_c ].max
  end

  # --------------------
  # Apparent Temperature (Steadman)
  # --------------------
  def apparent_temperature_c(temp_c, humidity, wind_speed_mps, cloud_pct, is_daytime)
    e_hpa = vapor_pressure(temp_c, humidity)

    apparent_temp =
      temp_c +
      0.33 * e_hpa -
      0.70 * wind_speed_mps -
      4.00

    if should_apply_solar_adjustment?(temp_c, wind_speed_mps, cloud_pct, is_daytime)
      apparent_temp += solar_adjustment(cloud_pct)
    end

    apparent_temp
  end

  def vapor_pressure(temp_c, humidity_pct)
    (humidity_pct / 100.0) *
      6.105 *
      Math.exp((17.27 * temp_c) / (237.7 + temp_c))
  end

  def should_apply_solar_adjustment?(temp_c, wind_speed_mps, cloud_pct, is_daytime)
    is_daytime &&
      wind_speed_mps < 2.0 &&
      cloud_pct < 40 &&
      temp_c >= 0.0 &&
      temp_c <= 15.0
  end

  def solar_adjustment(cloud_pct)
    clear_sky_factor = (40.0 - cloud_pct) / 40.0
    clear_sky_factor = [ [ clear_sky_factor, 0.0 ].max, 1.0 ].min

    solar_boost = 0.5 + (clear_sky_factor * 3.5)
    [ [ solar_boost, 0.0 ].max, 4.0 ].min
  end

  # --------------------
  # Utilities
  # --------------------
  def c_to_f(c)
    c * 9.0 / 5.0 + 32
  end

  def f_to_c(f)
    (f - 32) * 5.0 / 9.0
  end
end

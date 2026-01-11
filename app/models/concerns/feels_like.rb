module FeelsLike
  extend ActiveSupport::Concern

  def feels_like_c(temp_c:, humidity:, wind_speed_mps:)
    if cold_enough_for_wind_chill?(temp_c, wind_speed_mps)
      wind_chill_c(temp_c, wind_speed_mps)
    elsif hot_enough_for_heat_index?(temp_c, humidity)
      heat_index_c(temp_c, humidity)
    else
      temp_c
    end
  end

  # --------------------
  # Wind Chill
  # --------------------
  def cold_enough_for_wind_chill?(temp_c, wind_speed_mps)
    temp_c <= 10 && wind_speed_mps > 1.3
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
    temp_c >= 27 && humidity >= 40
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

    f_to_c(hi_f)
  end

  def c_to_f(c)
    c * 9.0 / 5.0 + 32
  end

  def f_to_c(f)
    (f - 32) * 5.0 / 9.0
  end
end

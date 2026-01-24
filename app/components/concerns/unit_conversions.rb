module UnitConversions
  def temp_fahrenheit(temp_celsius)
    return nil unless temp_celsius
    temp_celsius * 9.0 / 5.0 + 32.0
  end

  def rain_in_inches(rain_mm)
    return nil unless rain_mm
    rain_mm / 25.4
  end

  def wind_speed_mph(speed_mps)
    return nil unless speed_mps
    speed_mps * 2.23694
  end
end

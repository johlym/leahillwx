module WeatherUnitConversions
  extend ActiveSupport::Concern

  def celsius_to_fahrenheit(celsius)
    return nil if celsius.nil?
    (celsius * 9.0 / 5.0) + 32.0
  end

  def fahrenheit_to_celsius(fahrenheit)
    return nil if fahrenheit.nil?
    (fahrenheit - 32.0) * 5.0 / 9.0
  end

  def mm_to_inches(mm)
    return nil if mm.nil?
    mm / 25.4
  end

  def inches_to_mm(inches)
    return nil if inches.nil?
    inches * 25.4
  end

  def mps_to_mph(mps)
    return nil if mps.nil?
    mps * 2.23694
  end

  def mph_to_mps(mph)
    return nil if mph.nil?
    mph / 2.23694
  end

  def calculate_heat_degree_days(mean_temp_f, base_temp_f = 65.0)
    return nil if mean_temp_f.nil?
    [ 0.0, base_temp_f - mean_temp_f ].max
  end

  def calculate_cool_degree_days(mean_temp_f, base_temp_f = 65.0)
    return nil if mean_temp_f.nil?
    [ 0.0, mean_temp_f - base_temp_f ].max
  end
end

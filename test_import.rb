test_insert = '(1767867840,1,1,29.910780525844558,35.986507929112385,NULL,29.925731870395214,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,898.2560806521329,NULL,NULL,NULL,36.718073245130626,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,38.84000000000001,NULL,NULL,NULL,38.84000000000001,NULL,44.83863061964433,25,84.55999999999999,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0,NULL,NULL,NULL,NULL,92,38.84000000000001,NULL,NULL,NULL,NULL,NULL,29.461175041075155,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,38.84000000000001,119,1.1184709259696521,119,0.0009320591049747102,0.05592354629848261)'

values = test_insert.match(/\((.+)\)/)[1].split(',').map(&:strip)

def parse_value(val)
  val == 'NULL' ? nil : val
end

def fahrenheit_to_celsius(f)
  return nil if f.nil?
  (f.to_f - 32.0) * 5.0 / 9.0
end

def mph_to_ms(mph)
  return nil if mph.nil?
  mph.to_f * 0.44704
end

def inches_to_mm(inches)
  return nil if inches.nil?
  inches.to_f * 25.4
end

def inhg_to_mbar(inhg)
  return nil if inhg.nil?
  inhg.to_f * 33.8639
end

puts "Total values in array: #{values.count}"
puts ""
puts "Raw values at key positions:"
puts "  values[67] (outHumidity): #{values[67]}"
puts "  values[68] (outTemp): #{values[68]}"
puts "  values[74] (pressure): #{values[74]}"
puts "  values[75] (radiation): #{values[75]}"
puts "  values[76] (rain): #{values[76]}"
puts "  values[78] (rainRate): #{values[78]}"
puts "  values[109] (windDir): #{values[109]}"
puts "  values[110] (windGust): #{values[110]}"
puts "  values[113] (windSpeed): #{values[113]}"
puts ""

# Simulate import parsing
us_units = parse_value(values[1])&.to_i || 1
out_humidity = parse_value(values[67])
out_temp = parse_value(values[68])
pressure = parse_value(values[74])
radiation = parse_value(values[75])
rain = parse_value(values[76])
rain_rate = parse_value(values[78])
wind_dir = parse_value(values[109])
wind_gust = parse_value(values[110])
wind_speed = parse_value(values[113])

is_us_units = (us_units == 1)

out_temp_c = is_us_units ? fahrenheit_to_celsius(out_temp) : out_temp&.to_f
pressure_mbar = is_us_units ? inhg_to_mbar(pressure) : pressure&.to_f
wind_gust_ms = is_us_units ? mph_to_ms(wind_gust) : wind_gust&.to_f
wind_speed_ms = is_us_units ? mph_to_ms(wind_speed) : wind_speed&.to_f
rain_mm = is_us_units ? inches_to_mm(rain) : rain&.to_f
rain_rate_mm = is_us_units ? inches_to_mm(rain_rate) : rain_rate&.to_f

puts "After import conversions (what gets stored in DB):"
puts "  temperature: #{out_temp_c || 0.0}°C (from #{out_temp}°F)"
puts "  humidity: #{out_humidity&.to_i || 0}"
puts "  barometer_abs: #{pressure_mbar || 0.0} mbar (from #{pressure} inHg)"
puts "  wind_speed: #{wind_speed_ms || 0.0} m/s (from #{wind_speed} mph)"
puts "  gust_speed: #{wind_gust_ms || 0.0} m/s (from #{wind_gust} mph)"
puts "  wind_dir: #{wind_dir&.to_i || 0}°"
puts "  rain_day: #{rain_mm || 0.0} mm (from #{rain} inches)"
puts "  rain_rate: #{rain_rate_mm || 0.0} mm/hr (from #{rain_rate} inches/hr)"
puts ""
puts "Expected values (from your sample):"
puts "  outHumidity: 92"
puts "  outTemp: 38.84°F → 3.8°C"
puts "  Last 6 values in record: #{values[-6..-1].join(', ')}"
puts ""
puts "What are these last values?"
puts "  values[108]: #{values[108]}"
puts "  values[109]: #{values[109]}"
puts "  values[110]: #{values[110]}"
puts "  values[111]: #{values[111]}"
puts "  values[112]: #{values[112]}"
puts "  values[113]: #{values[113]}"
puts "  values[114]: #{values[114] if values[114]}"
puts "  values[115]: #{values[115] if values[115]}"

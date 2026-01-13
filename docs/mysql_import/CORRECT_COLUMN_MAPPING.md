# Correct WeeWX → Rails Column Mapping

## Issue Found

The original import incorrectly mapped `gust_speed` to WeeWX's `windGustDir` (wind gust direction) instead of `windGust` (actual gust speed). This caused:

- Gust speeds showing as 150-350 mph (actually degrees)
- Dominant wind direction always N/A (calm winds filtered out)

## Correct Mapping

| Rails Field         | WeeWX Column  | Notes                         |
| ------------------- | ------------- | ----------------------------- |
| `reading_date_time` | `dateTime`    | Unix timestamp → datetime     |
| `barometer_abs`     | `pressure`    | Absolute pressure             |
| `barometer_rel`     | `barometer`   | Relative pressure             |
| `gust_speed`        | `windGust`    | **CORRECT** (not windGustDir) |
| `humidity`          | `outHumidity` | Cast to integer               |
| `light`             | `luminosity`  | Light sensor reading          |
| `rain_day`          | `rain`        | Rain accumulation             |
| `rain_rate`         | `rainRate`    | Rate of rainfall              |
| `temperature`       | `outTemp`     | Outdoor temperature           |
| `uv`                | `UV`          | Cast to integer               |
| `uvi`               | `UV`          | Keep as float                 |
| `wind_dir`          | `windDir`     | Wind direction in degrees     |
| `wind_speed`        | `windSpeed`   | Wind speed                    |

## WeeWX Wind Columns

- `windSpeed` - Current wind speed
- `windDir` - Current wind direction (degrees)
- `windGust` - Wind gust speed ← **Use this for gust_speed**
- `windGustDir` - Wind gust direction ← **NOT the gust speed!**
- `windrun` - Total wind run (not used)

## Unit Conversion Required

WeeWX stores data with a `usUnits` field:

- `usUnits=1`: US units (Fahrenheit, inHg, mph, inches)
- `usUnits=16`: Metric units (Celsius, mbar, m/s, mm)

Rails app expects metric units, so import script converts:

- Temperature: °F → °C `(f - 32) * 5/9`
- Pressure: inHg → mbar `inhg * 33.8639`
- Wind speed: mph → m/s `mph * 0.44704`
- Rain: inches → mm `inches * 25.4`

## Data Import Strategy

1. Get fresh SQL dump from WeeWX database
2. Clear existing weather_measurements and reports
3. Import with corrected column mapping AND unit conversion
4. Regenerate all climatological reports

# WeeWX MySQL → Rails Column Mapping

## Rails Schema Fields (weather_measurements)

| Field               | Type     | Required |
| ------------------- | -------- | -------- |
| `reading_date_time` | datetime | ✓        |
| `barometer_abs`     | float    | ✓        |
| `barometer_rel`     | float    | ✓        |
| `day_max_wind`      | float    | ✓        |
| `gust_speed`        | float    | ✓        |
| `humidity`          | integer  | ✓        |
| `light`             | float    | ✓        |
| `rain_day`          | float    | ✓        |
| `rain_event`        | float    | ✓        |
| `rain_rate`         | float    | ✓        |
| `temperature`       | float    | ✓        |
| `uv`                | integer  | ✓        |
| `uvi`               | float    | ✓        |
| `wind_dir`          | integer  | ✓        |
| `wind_speed`        | float    | ✓        |

---

## Proposed WeeWX → Rails Mapping

| Rails Field         | WeeWX Column                 | Notes                                          |
| ------------------- | ---------------------------- | ---------------------------------------------- |
| `reading_date_time` | `dateTime`                   | Unix timestamp → datetime                      |
| `barometer_abs`     | `pressure`                   | ?                                              |
| `barometer_rel`     | `barometer`                  | ?                                              |
| `day_max_wind`      | **???**                      | WeeWX doesn't track daily max wind             |
| `gust_speed`        | `windGust`                   | ✓                                              |
| `humidity`          | `outHumidity`                | Cast to integer                                |
| `light`             | `radiation` or `luminosity`? | Need clarification                             |
| `rain_day`          | **???**                      | WeeWX `rain` is interval, not daily cumulative |
| `rain_event`        | **???**                      | WeeWX doesn't track rain events                |
| `rain_rate`         | `rainRate`                   | ✓                                              |
| `temperature`       | `outTemp`                    | ✓                                              |
| `uv`                | `UV`                         | Cast to integer                                |
| `uvi`               | `UV`                         | Keep as float?                                 |
| `wind_dir`          | `windDir`                    | Cast to integer                                |
| `wind_speed`        | `windSpeed`                  | ✓                                              |

---

## Questions to Resolve

### 1. Barometer Mapping

WeeWX has `altimeter`, `barometer`, and `pressure`. Which should map to `barometer_abs` vs `barometer_rel`?

From example record:

- `altimeter` = 31.57
- `barometer` = 31.10
- `pressure` = 31.10

**Answer:** barometer_abs is the direct measurement from the sensor, while barometer_rel is the pressure adjusted to sea level. We should map barometer_abs and calculate barometer_rel from barometer_abs given 416 feet above sea level. (SEE NOTE ABOUT usUnits below)

Common adjustment: Roughly 1 hPa or 0.03 inHg per 10 meters/30 feet of elevation.

---

### 2. Missing Daily/Event Fields

`day_max_wind`, `rain_day`, and `rain_event` don't exist in WeeWX's per-interval records.

Options:

- [x] Set to `0` or some default value
- [ ] Calculate `day_max_wind` by tracking max windGust per day during import
- [ ] Other: **\*\***\_\_\_**\*\***

**Answer:** Set to 0

---

### 3. Light Field

Should `light` map to `radiation` (solar radiation W/m²) or `luminosity`?

**Answer:** `light` is in `lux` units. `radiation` is in `W/m²`. These are different measurements and should not be confused. That said, we should convert `radiation` to `lux` for consistency. Approximate the conversion of 0.0084 W/m² per lux. Ex: 100000 lux = 840 W/m².

If `radiation` is zero, `lux` should be `0`.

---

### 4. UV Fields

You have both `uv` (integer) and `uvi` (float). WeeWX only has one `UV` field. Should both use the same source value?

**Answer:** No. Only write to `uv` field.

---

### 5. Units

The example shows `usUnits=1` (US customary). Your model has conversion methods suggesting you store metric.

Do the WeeWX values need unit conversion, or are they already in the expected units?

**Answer:** This implies the measurement are in US customary units, so they need to be converted to metric units. (ex: temperature to C, pressure to hPa/mbar, wind speed to m/s, etc.)

---

### 6. Data Source

Will you be parsing a MySQL dump file (SQL INSERT statements) or connecting directly to the MySQL database?

**Answer:** Parsing a MySQL dump file (SQL INSERT statements).

---

## Cutoff Date

First measurement in new database: **2026-01-05 00:15:02.15**

Import should stop before this timestamp to prevent duplication.

### Examples

```
INSERT INTO `archive` VALUES (1640323200,1,5,31.569787808878907,28.384353609230672,NULL,31.099992045582578,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1659.9494203402521,NULL,NULL,11.927511641087776,27.137580718541052,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,32.61095816803817,NULL,NULL,11.985751716763813,32.61095816803817,NULL,31.079409937845018,29.999681825580627,63.000159087209674,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,79.99976136747722,32.61095816803817,0,NULL,NULL,NULL,NULL,31.099992045582578,0,0,0,0,12.00634863505469,26.919313556415936,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,12.042989544468853,0,0,NULL,0,32.61095816803817,359.99742291983415,0.00014130766857078925,359.9957607699429,0.000003314340594413172,0.000039772087132958067)
```

```
DROP TABLE IF EXISTS `archive`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `archive` (
  `dateTime` int NOT NULL,
  `usUnits` int NOT NULL,
  `interval` int NOT NULL,
  `altimeter` double DEFAULT NULL,
  `appTemp` double DEFAULT NULL,
  `appTemp1` double DEFAULT NULL,
  `barometer` double DEFAULT NULL,
  `batteryStatus1` double DEFAULT NULL,
  `batteryStatus2` double DEFAULT NULL,
  `batteryStatus3` double DEFAULT NULL,
  `batteryStatus4` double DEFAULT NULL,
  `batteryStatus5` double DEFAULT NULL,
  `batteryStatus6` double DEFAULT NULL,
  `batteryStatus7` double DEFAULT NULL,
  `batteryStatus8` double DEFAULT NULL,
  `cloudbase` double DEFAULT NULL,
  `co` double DEFAULT NULL,
  `co2` double DEFAULT NULL,
  `consBatteryVoltage` double DEFAULT NULL,
  `dewpoint` double DEFAULT NULL,
  `dewpoint1` double DEFAULT NULL,
  `ET` double DEFAULT NULL,
  `extraHumid1` double DEFAULT NULL,
  `extraHumid2` double DEFAULT NULL,
  `extraHumid3` double DEFAULT NULL,
  `extraHumid4` double DEFAULT NULL,
  `extraHumid5` double DEFAULT NULL,
  `extraHumid6` double DEFAULT NULL,
  `extraHumid7` double DEFAULT NULL,
  `extraHumid8` double DEFAULT NULL,
  `extraTemp1` double DEFAULT NULL,
  `extraTemp2` double DEFAULT NULL,
  `extraTemp3` double DEFAULT NULL,
  `extraTemp4` double DEFAULT NULL,
  `extraTemp5` double DEFAULT NULL,
  `extraTemp6` double DEFAULT NULL,
  `extraTemp7` double DEFAULT NULL,
  `extraTemp8` double DEFAULT NULL,
  `forecast` double DEFAULT NULL,
  `hail` double DEFAULT NULL,
  `hailBatteryStatus` double DEFAULT NULL,
  `hailRate` double DEFAULT NULL,
  `heatindex` double DEFAULT NULL,
  `heatindex1` double DEFAULT NULL,
  `heatingTemp` double DEFAULT NULL,
  `heatingVoltage` double DEFAULT NULL,
  `humidex` double DEFAULT NULL,
  `humidex1` double DEFAULT NULL,
  `inDewpoint` double DEFAULT NULL,
  `inHumidity` double DEFAULT NULL,
  `inTemp` double DEFAULT NULL,
  `inTempBatteryStatus` double DEFAULT NULL,
  `leafTemp1` double DEFAULT NULL,
  `leafTemp2` double DEFAULT NULL,
  `leafWet1` double DEFAULT NULL,
  `leafWet2` double DEFAULT NULL,
  `lightning_distance` double DEFAULT NULL,
  `lightning_disturber_count` double DEFAULT NULL,
  `lightning_energy` double DEFAULT NULL,
  `lightning_noise_count` double DEFAULT NULL,
  `lightning_strike_count` double DEFAULT NULL,
  `luminosity` double DEFAULT NULL,
  `maxSolarRad` double DEFAULT NULL,
  `nh3` double DEFAULT NULL,
  `no2` double DEFAULT NULL,
  `noise` double DEFAULT NULL,
  `o3` double DEFAULT NULL,
  `outHumidity` double DEFAULT NULL,
  `outTemp` double DEFAULT NULL,
  `outTempBatteryStatus` double DEFAULT NULL,
  `pb` double DEFAULT NULL,
  `pm10_0` double DEFAULT NULL,
  `pm1_0` double DEFAULT NULL,
  `pm2_5` double DEFAULT NULL,
  `pressure` double DEFAULT NULL,
  `radiation` double DEFAULT NULL,
  `rain` double DEFAULT NULL,
  `rainBatteryStatus` double DEFAULT NULL,
  `rainRate` double DEFAULT NULL,
  `referenceVoltage` double DEFAULT NULL,
  `rxCheckPercent` double DEFAULT NULL,
  `signal1` double DEFAULT NULL,
  `signal2` double DEFAULT NULL,
  `signal3` double DEFAULT NULL,
  `signal4` double DEFAULT NULL,
  `signal5` double DEFAULT NULL,
  `signal6` double DEFAULT NULL,
  `signal7` double DEFAULT NULL,
  `signal8` double DEFAULT NULL,
  `snow` double DEFAULT NULL,
  `snowBatteryStatus` double DEFAULT NULL,
  `snowDepth` double DEFAULT NULL,
  `snowMoisture` double DEFAULT NULL,
  `snowRate` double DEFAULT NULL,
  `so2` double DEFAULT NULL,
  `soilMoist1` double DEFAULT NULL,
  `soilMoist2` double DEFAULT NULL,
  `soilMoist3` double DEFAULT NULL,
  `soilMoist4` double DEFAULT NULL,
  `soilTemp1` double DEFAULT NULL,
  `soilTemp2` double DEFAULT NULL,
  `soilTemp3` double DEFAULT NULL,
  `soilTemp4` double DEFAULT NULL,
  `supplyVoltage` double DEFAULT NULL,
  `txBatteryStatus` double DEFAULT NULL,
  `UV` double DEFAULT NULL,
  `uvBatteryStatus` double DEFAULT NULL,
  `windBatteryStatus` double DEFAULT NULL,
  `windchill` double DEFAULT NULL,
  `windDir` double DEFAULT NULL,
  `windGust` double DEFAULT NULL,
  `windGustDir` double DEFAULT NULL,
  `windrun` double DEFAULT NULL,
  `windSpeed` double DEFAULT NULL,
  PRIMARY KEY (`dateTime`),
  UNIQUE KEY `dateTime` (`dateTime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
```

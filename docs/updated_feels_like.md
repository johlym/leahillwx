Below is a **clean, implementation-ready spec** you can paste directly into **Claude Sonnet 4.5**.
It is written as a **clear algorithm + requirements doc**, not conversational prose.

---

# Feels-Like Temperature Algorithm Specification

## Goal

Implement a **“feels like” temperature** calculation that closely matches outputs from major consumer weather platforms (Apple Weather, AccuWeather, The Weather Channel), rather than strict NOAA-only behavior.

The algorithm must:

- Use **physically valid formulas**
- Apply them **conditionally**
- Include a **solar radiation heuristic**
- Avoid misuse of heat index and wind chill

---

## Inputs (required)

All calculations are in **metric units internally**.

```text
temp_c        Float   # Air temperature in °C
humidity_pct  Float   # Relative humidity (0–100)
wind_mps      Float   # Wind speed in meters per second
cloud_pct     Float   # Cloud cover percentage (0–100)
is_daytime    Boolean # True if sun is above horizon
```

---

## Output

```text
feels_like_c  Float   # Apparent (“feels like”) temperature in °C
```

---

## Decision Tree (authoritative)

Apply **exactly one** of the following paths:

1. **Wind Chill**
2. **Heat Index**
3. **Apparent Temperature + Solar Adjustment**

---

## 1️⃣ Wind Chill (cold + wind only)

### Apply ONLY if:

```text
temp_c ≤ 10.0 AND wind_mps ≥ 1.3
```

### Formula (official, metric):

```text
wind_chill_c =
  13.12 +
  0.6215 * temp_c -
  11.37 * (wind_mps * 3.6) ^ 0.16 +
  0.3965 * temp_c * (wind_mps * 3.6) ^ 0.16
```

> Convert m/s → km/h by multiplying by 3.6.

Return immediately.
**Do not apply any other adjustments.**

---

## 2️⃣ Heat Index (hot only)

### Apply ONLY if:

```text
temp_c ≥ 27.0 AND humidity_pct ≥ 40
```

### Use:

- NOAA Rothfusz regression
- Metric or Fahrenheit implementation acceptable
- Convert back to °C if using °F internally

Return immediately.
**Do not apply solar or wind adjustments afterward.**

---

## 3️⃣ Apparent Temperature (default path)

This path handles:

- Cool, calm days
- Mild weather
- Humid but non-hot conditions

### 3.1 Vapor pressure

```text
e_hpa =
  (humidity_pct / 100.0) *
  6.105 *
  exp((17.27 * temp_c) / (237.7 + temp_c))
```

---

### 3.2 Steadman Apparent Temperature

```text
apparent_temp_c =
  temp_c +
  0.33 * e_hpa -
  0.70 * wind_mps -
  4.00
```

---

## 4️⃣ Solar Radiation Adjustment (critical realism step)

This step is what causes:

> “43°F air temperature → feels like ~49°F”
> on calm, sunny winter days.

### Apply ONLY if all conditions are met:

```text
is_daytime == true
wind_mps < 2.0
cloud_pct < 40
temp_c between 0.0 and 15.0 (inclusive)
```

---

### Solar adjustment heuristic

```text
clear_sky_factor = (40 - cloud_pct) / 40.0
clear_sky_factor clamped to range [0.0, 1.0]

solar_boost_c =
  clamp(
    0.5 + (clear_sky_factor * 3.5),
    0.0,
    4.0
  )
```

Add to apparent temperature:

```text
apparent_temp_c += solar_boost_c
```

---

## Final Return

```text
return apparent_temp_c
```

---

## Behavioral Guarantees

This implementation will:

- Never apply **heat index below ~80°F**
- Never apply **wind chill without sufficient wind**
- Allow **humidity to influence cool temperatures**
- Raise feels-like temperature on **calm, sunny, cool days**
- Closely match **Apple Weather** output
- Slightly under-boost compared to **AccuWeather** (intentional)

---

## Notes for Implementation

- All constants are intentionally tuned for **human comfort realism**, not strict climatology
- Do **not** combine wind chill or heat index with solar boosts
- Keep all internal calculations in metric
- Round only at the presentation layer (via the existing `.to_farenheit` method in components.)

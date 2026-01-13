# Calculating the Dominant Wind Direction (Daily)

This document describes a practical and defensible method for calculating the **dominant wind direction** for a given day using discrete wind measurements (direction and speed) collected over time.

The approach accounts for the **circular nature of wind direction** and weights directions by wind speed, producing a result that reflects where the wind was _meaningfully coming from_ during the day.

---

## Why You Can’t Use a Simple Average

Wind direction is a circular measurement (0–360°):

- 359° and 1° are only 2° apart, but a naive average yields 180° ❌
- Calm periods should not influence direction
- Strong winds should matter more than light winds

Because of this, wind directions must be treated as **vectors**, not scalars.

---

## Required Inputs

For each observation during the day:

- **Direction** (`θ`) in degrees (0–360, meteorological convention: where the wind is coming _from_)
- **Speed** (`v`) in consistent units (m/s, km/h, mph — any unit works)

Example dataset:

| Time  | Direction (°) | Speed |
| ----- | ------------- | ----- |
| 00:00 | 270           | 5.2   |
| 00:05 | 275           | 6.1   |
| 00:10 | 260           | 3.8   |

---

## Step-by-Step Calculation

### 1. Convert Degrees to Radians

Most math libraries use radians:

```
θ_rad = θ_deg × π / 180
```

---

### 2. Convert Each Observation to Vector Components

Weight each direction by its wind speed:

```
x = v × cos(θ_rad)
y = v × sin(θ_rad)
```

This converts each reading into a 2-D vector.

---

### 3. Sum All Vectors for the Day

```
X = Σ(v × cos(θ_rad))
Y = Σ(v × sin(θ_rad))
```

- Calm winds (`v ≈ 0`) contribute negligibly
- Stronger winds pull the result toward their direction

---

### 4. Compute the Resultant Direction

```
θ_result = atan2(Y, X)
```

Convert back to degrees:

```
θ_deg = θ_result × 180 / π
```

Normalize to a compass bearing:

```
if θ_deg < 0:
  θ_deg += 360
```

This value is the **dominant wind direction** for the day.

---

## Optional Enhancements

### Filter Out Calm Winds

To reduce noise:

```
ignore readings where v < 0.5 m/s
```

---

### Convert to Cardinal Direction

Map the resulting angle to compass points:

| Range (°)   | Direction |
| ----------- | --------- |
| 337.5–22.5  | N         |
| 22.5–67.5   | NE        |
| 67.5–112.5  | E         |
| 112.5–157.5 | SE        |
| 157.5–202.5 | S         |
| 202.5–247.5 | SW        |
| 247.5–292.5 | W         |
| 292.5–337.5 | NW        |

---

## Why This Method Works

- Handles circular values correctly
- Reflects _how strong_ the wind was from each direction
- Matches methods used in meteorology and climatology
- Robust to outliers and short-term variability

---

## Summary

To calculate dominant daily wind direction:

1. Convert direction to radians
2. Weight direction by wind speed
3. Sum vector components
4. Convert back to degrees
5. Normalize to 0–360°

This produces a physically meaningful and statistically correct dominant wind direction for the day.

---

## References

- Vector averaging for circular data
- Meteorological wind conventions
- Trigonometric vector resolution

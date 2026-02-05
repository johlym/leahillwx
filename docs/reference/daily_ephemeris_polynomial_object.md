# Spec: Daily Ephemeris Polynomial Object (Sun / Moon)

## Purpose

Generate a **single-day ephemeris data object** that allows **continuous, high-precision evaluation** of an astronomical body’s observable properties (e.g. altitude, azimuth) in the browser **without runtime trigonometry**, suitable for interactive canvas charts where cursor position, plotted curve, and tooltip must remain perfectly aligned.

This object must support:

- smooth rendering
- exact hover evaluation
- bounded numerical error
- fast evaluation on low-power devices

---

## Time Domain

- The object represents **exactly one civil day**
- All internal time values are **seconds since local midnight**
- Valid time domain:

  ```
  t ∈ [0, 86400]
  ```

---

## Top-Level Object Shape

```json
{
  "t": <number>,
  "m": 86400,
  "e": { ... },
  "o": { ... }
}
```

### Fields

| Key | Type   | Meaning                                                        |
| --- | ------ | -------------------------------------------------------------- |
| `t` | number | Unix timestamp (seconds) of local midnight for the modeled day |
| `m` | number | Model span in seconds (always `86400`)                         |
| `e` | object | Discrete astronomical events (rise, set, transit, etc.)        |
| `o` | object | Continuous observable models (altitude, azimuth, etc.)         |

---

## Events Section (`e`)

### Shape

```json
"e": {
  "<body>": [
    { "s": <seconds>, "t": <event_type_id> },
    ...
  ]
}
```

### Rules

- `s` = seconds since midnight
- `t` = integer event type code (opaque, consumer-defined)
- Events **must be authoritative**, not derived from polynomials
- Events may include (but are not limited to):
  - rise
  - set
  - upper transit
  - lower transit

Events are informational and **do not drive rendering math**.

---

## Observables Section (`o`)

### Shape

```json
"o": {
  "<body>": {
    "<observable>": [ <segment>, <segment>, ... ]
  }
}
```

Example observables:

- `"alt"` (altitude, degrees)
- `"az"` (azimuth, degrees, unwrapped)

---

## Polynomial Segment Definition

Each observable is represented as a **piecewise cubic polynomial** over time.

### Segment Shape

```json
{
  "e": <end_time_seconds>,
  "p": [a0, a1, a2, a3]
}
```

### Mathematical Meaning

Let:

- `t0` = start time of the segment (implicit)
- `dt = t - t0`
- `p = [a0, a1, a2, a3]`

Then:

```
value(t) =
  a0
+ a1 * dt
+ a2 * dt²
+ a3 * dt³
```

---

## Segment Rules

1. **Segments must be contiguous**
   - First segment starts at `t = 0`
   - Each segment’s start = previous segment’s `e`
   - Final segment must end at `e = 86400`

2. **Segments may be non-uniform**
   - Dense segmentation is expected near:
     - horizon crossings
     - azimuth wrap points
     - extrema (rise/set/transit)

   - Sparse segmentation is acceptable during smooth motion

3. **Large coefficients are allowed**
   - Coefficients may be numerically large
   - Stability is guaranteed by **small segment duration**
   - Accuracy matters only inside the segment interval

4. **No discontinuities**
   - Value continuity is required at segment boundaries
   - First derivative continuity is preferred but not required

---

## Observable-Specific Rules

### Altitude (`alt`)

- Units: **degrees**
- Reference: geometric altitude (topocentric, refraction already applied if desired)
- No hard clipping at horizon
- Altitude may go below zero smoothly

### Azimuth (`az`)

- Units: **degrees**
- Azimuth must be **unwrapped**
  - May exceed ±360°
  - Must be continuous

- Consumer may apply modulo later if needed

---

## Accuracy Requirements

- Maximum absolute error:
  **≤ 0.01°** over the entire day
- Error must remain bounded inside each segment
- Segment breakpoints should be inserted automatically to enforce this bound

---

## Consumer Evaluation Algorithm (Reference)

Given time `t`:

1. Clamp `t` to `[0, 86400]`
2. Find the segment where:

   ```
   segment.start ≤ t ≤ segment.e
   ```

3. Compute:

   ```
   dt = t - segment.start
   ```

4. Evaluate cubic polynomial

This must be O(1) or O(log n) per query.

---

## Design Intent (Important)

- This object is **not sampled data**
- It is **not a spline knot list**
- It is **not meant for interpolation**
- It is an **analytic representation**

The consumer must be able to:

- draw a curve using sampled evaluations
- evaluate at arbitrary sub-second times
- drive hover interaction without snapping artifacts

---

## Explicit Non-Goals

- Do NOT include rendering metadata
- Do NOT include CSS, canvas, or UI concerns
- Do NOT include timezone conversion logic
- Do NOT include leap second handling

---

## Validation Checklist

An implementation is correct if:

- Cursor X → time → value produces a smooth, stable result
- No visual drift exists between curve, cursor, and tooltip
- Evaluation is fast enough for real-time interaction
- No trigonometric functions are required at runtime

---

## Summary (one-sentence)

> This object represents a one-day, piecewise-cubic ephemeris for astronomical observables, enabling exact, continuous evaluation in the browser without runtime orbital math.

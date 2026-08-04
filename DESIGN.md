## Overview

This design is a dark-mode, data-dense weather dashboard homepage with a technical and real-time monitoring feel. The mood is utilitarian, atmospheric, and slightly premium, combining strong numerical hierarchy with compact telemetry-style labels. It feels closer to an operational dashboard than a marketing landing page.

The visual language emphasizes live environmental data, alerts, and status visibility. Layouts are modular and card-based, using a responsive grid with consistent spacing, subdued borders, and restrained color accents to indicate weather conditions, severity, and system state. Surfaces are layered through opacity and tone rather than heavy shadows.

The overall impression should be precise, modern, and calm under pressure: a weather intelligence interface designed for fast scanning, not decorative browsing.

## Colors

- **Primary**: `slate-950` for the page background, major section backgrounds, and overall dark canvas.
- **Secondary**: `slate-900` / `slate-900/40` / `slate-900/50` for cards, panels, nav highlights, and modular content containers.
- **Tertiary**: `slate-800` for borders inside cards, dividers, table rules, and structural separation.
- **Neutral Text**:
  - `slate-100` / `white` for primary content and key metrics
  - `slate-300` / `slate-400` for supporting values and navigation
  - `slate-500` / `slate-600` for metadata, timestamps, and low-emphasis text

### Functional Accent Colors
- **Sky Accent**: `sky-400`, `sky-500` for weather branding, low temperatures, atmospheric highlights, and selected icons.
- **Success / Live Accent**: `emerald-400`, `emerald-500` for live status, positive state labels, active feeds, and safe/low metrics.
- **Warning Accent**: `amber-400` for sun/weather icons, moderate readings, and solar/celestial emphasis.
- **Danger Accent**: `red-400`, `red-500`, `red-900` for alert banners and hazard-related content.
- **Hot Temperature Accent**: `rose-400` for daily highs and warm-value emphasis.
- **Night / Astronomical Accent**: `indigo-400` for moon/planet/night forecasting cues.

The palette is predominantly dark slate with selective environmental accents. Bright colors are used meaningfully and sparingly to encode weather semantics rather than brand expression.

## Typography

Typography is split between bold geometric display text for major readings and monospaced text for UI precision and telemetry detail.

- **Headline Font**: `Space Grotesk`
- **Body Font**: `JetBrains Mono`
- **Label Font**: `JetBrains Mono`

### Type Behavior
- Major numerical values, section headings, and key temperatures use `Space Grotesk` with heavy weights and tight tracking.
- Body text, metadata, timestamps, labels, table content, and navigation use `JetBrains Mono`.
- Labels are frequently uppercase with expanded tracking to create a control-panel or instrumentation feel.
- Font sizes range from very small utility text (`text-[9px]`, `text-[10px]`, `text-xs`) up to oversized hero metrics (`text-7xl`, `text-8xl`).
- Data hierarchy is strong: huge current temperature, medium card metrics, and tiny operational metadata.

Overall, typography should feel exact, legible, and system-oriented, with enough display contrast to make the key weather readings dominant.

## Elevation

This design relies on tonal layering, translucent dark panels, soft blur, and thin borders instead of traditional shadow depth.

- Cards commonly use semi-transparent dark fills like `bg-slate-900/40` or `bg-slate-900/50`.
- Borders are consistently visible and low-contrast, usually `border-slate-900` or `border-slate-800`.
- Some hero cards use `backdrop-blur-sm` to create subtle glass-like separation.
- Ambient glow appears selectively, such as the soft `sky-500/5` blurred circle in the hero temperature panel.
- Images and overlays use gradients for readability rather than drop shadow.

Depth should feel clean and layered, like a high-end monitoring UI, not soft or heavily elevated.

## Components

- **Alert Banner**: Full-width top strip using translucent dark red background, red border, small mono text, and animated red status dot. Designed to signal urgency without overwhelming the interface.
- **Navigation**: Dark header with compact horizontal nav. Active item uses filled `slate-900` styling. Links are muted by default and brighten on hover. Branding pairs a weather icon tile with stacked title and live indicator.
- **Status Indicators**: Tiny pulsing or pinging dots paired with uppercase labels such as “LIVE” or “Active.” These are critical to the real-time monitoring feel.
- **Hero Metric Card**: Large rounded card with oversized current temperature, supporting condition icon/text, and a 3-column stats footer. This is the primary focal module.
- **Data Cards**: Reusable metric cards with small uppercase labels, large numeric values, and concise secondary information. Used for humidity, UV, AQI, rainfall, dew point, cloud base, and hazards.
- **Badge Pills**: Small rounded labels with tinted backgrounds such as `emerald-500/10` or `amber-500/10`. Used for categorical status like “Low,” “Moderate,” or “Contained.”
- **Progress Bars**: Thin horizontal bars with dark track and colored fill. Used for UV, AQI, and planetary visibility/activity-like summaries.
- **Dial / Compass Widget**: Circular bordered indicator with directional labels and a gradient needle. It presents wind in a compact, instrument-like way.
- **Celestial Arc Widget**: Minimal SVG arc with dotted path, position marker, and sunrise/sunset labels. Designed as a quiet informational visualization.
- **Forecast Tiles**: Small repeated hourly blocks with icon, time, temperature, and precipitation chance. Each tile is rounded, bordered, and centered.
- **Forecast Rows**: Daily forecast entries use horizontal list rows with hover background shift, icon, summary, and high/low temperature alignment.
- **Camera Feed Cards**: Image tiles with dark gradient overlays and tiny uppercase captions. Hover scale on images adds subtle interaction.
- **Data Table**: Compact earthquake table with uppercase header row, thin dividers, muted metadata, and colored magnitude badges. Location links use `sky-400` with underline on hover.
- **Footer**: Minimal utility footer with disclaimer text and muted legal/API links.

## Do's and Don'ts

- **Do** use a dark slate-first palette with high readability and restrained color coding.
- **Do** emphasize real-time status through small animated indicators and timestamp metadata.
- **Do** combine bold display numerics with monospaced utility copy.
- **Do** build layouts from modular cards with thin borders, rounded corners, and consistent spacing.
- **Do** use accent colors semantically: red for alerts, emerald for live/safe, amber for warnings or sun, sky for atmospheric/weather cues.
- **Do** maintain strong hierarchy for current conditions and key metrics.

- **Don't** introduce bright multicolor gradients or saturated decorative backgrounds.
- **Don't** use soft consumer-style shadows, glassmorphism excess, or playful motion.
- **Don't** replace the monospaced UI text system with a generic sans-serif body style.
- **Don't** make cards overly rounded or bubbly; radii are softened but still controlled.
- **Don't** overload the interface with unnecessary embellishment; every accent should communicate state or condition.

## Info
This design.md file was generated using Shuffle (https://shuffle.dev) - an AI-powered editor for building beautiful, high-quality websites.
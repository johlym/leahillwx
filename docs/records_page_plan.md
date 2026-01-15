# Records Page Implementation Plan

## Overview

Build a Records page to track and display weather records for selectable time periods (current year default, all-time option).

## Architecture Decision: Pre-computed Records Model

### Rationale

- **Performance**: Calculating records on-the-fly would require heavy aggregations on potentially millions of `weather_measurements` rows
- **Complexity**: Records like "consecutive days with/without rain" and "longest stretch of 0 mph wind" require complex sequential analysis
- **Update Frequency**: Records change infrequently, making caching optimal

### Database Schema

```ruby
create_table :records do |t|
  t.string :scope, null: false  # 'all_time' or 'yearly'
  t.integer :year               # null for all_time, required for yearly

  # Temperature Records (16 columns)
  t.float :highest_temp
  t.datetime :highest_temp_at
  t.float :lowest_temp
  t.datetime :lowest_temp_at
  t.float :highest_apparent_temp
  t.datetime :highest_apparent_temp_at
  t.float :lowest_apparent_temp
  t.datetime :lowest_apparent_temp_at
  t.float :highest_heat_index
  t.datetime :highest_heat_index_at
  t.float :lowest_wind_chill
  t.datetime :lowest_wind_chill_at
  t.float :largest_temp_range
  t.date :largest_temp_range_date
  t.float :smallest_temp_range
  t.date :smallest_temp_range_date

  # Wind Records (6 columns)
  t.float :strongest_gust
  t.datetime :strongest_gust_at
  t.float :highest_wind_run          # Daily total wind miles
  t.date :highest_wind_run_date
  t.integer :longest_calm_hours      # Consecutive hours of 0 mph wind
  t.datetime :longest_calm_start_at

  # Rain Records (10 columns)
  t.float :highest_daily_rain
  t.date :highest_daily_rain_date
  t.float :highest_rain_rate
  t.datetime :highest_rain_rate_at
  t.integer :wettest_month           # 1-12
  t.integer :wettest_month_year
  t.float :wettest_month_total
  t.integer :consecutive_rain_days
  t.date :consecutive_rain_start_date
  t.integer :consecutive_dry_days
  t.date :consecutive_dry_start_date

  # Humidity Records (8 columns)
  t.integer :highest_humidity
  t.datetime :highest_humidity_at
  t.integer :lowest_humidity
  t.datetime :lowest_humidity_at
  t.float :highest_dew_point
  t.datetime :highest_dew_point_at
  t.float :lowest_dew_point
  t.datetime :lowest_dew_point_at

  # Barometer Records (6 columns)
  t.float :highest_pressure
  t.datetime :highest_pressure_at
  t.float :lowest_pressure
  t.datetime :lowest_pressure_at
  t.float :largest_pressure_swing    # Largest single-day swing
  t.date :largest_pressure_swing_date

  # Sun Records (2 columns)
  t.float :highest_solar
  t.datetime :highest_solar_at

  t.timestamps

  t.index [:scope, :year], unique: true
end
```

## Record Categories & Metrics

### Temperature Records

- Highest Temperature
- Lowest Temperature
- Highest Apparent Temperature (feels like)
- Lowest Apparent Temperature (feels like)
- Highest Heat Index
- Lowest Wind Chill
- Largest Daily Temperature Range
- Smallest Daily Temperature Range

### Wind Records

- Strongest Gust
- Highest Daily Wind Run (total miles of wind in a day)
- Longest Stretch of 0 mph wind (in hours)

### Rain Records

- Highest Daily Rainfall
- Highest Daily Rain Rate
- Month with Most Rain
- Consecutive Days with Rain
- Consecutive Days without Rain

### Humidity Records

- Highest Humidity
- Lowest Humidity
- Highest Dew Point
- Lowest Dew Point

### Barometer Records

- Highest Pressure
- Lowest Pressure
- Largest Pressure Swing (single day)

### Sun Records

- Highest Solar Irradiance

## Implementation Components

### 1. Model Layer

- `Record` model with validations and scopes
- Enum for `scope` field
- Methods to format display values

### 2. Service Layer

- `RecordCalculator` service to compute all records from `weather_measurements`
- Handles both all-time and yearly scopes
- Methods for each category of records
- Efficient SQL queries with aggregations

### 3. Controller Layer

- `RecordsController` with `index` action
- Handles year parameter for filtering
- Loads current year and all-time records

### 4. View Layer

- `RecordsTableComponent` (ViewComponent with sidecar structure)
  - `records_table_component.rb` - Component class
  - `records_table_component/records_table_component.html.erb` - Template in subfolder
- Organized into sections by category
- Displays two columns: selected year and all-time
- Year selector dropdown for comparison

### 5. Background Jobs

- Sidekiq job scheduled nightly at 12:02 AM America/Los_Angeles
- Recalculates all records for current year and all-time

### 6. Rake Tasks

- `rake records:populate` - Initial population
- `rake records:recalculate` - Full recalculation
- `rake records:update_year[year]` - Update specific year

## Update Strategy

### Automated Nightly Updates

- Sidekiq job scheduled at 12:02 AM America/Los_Angeles
- Recalculates all records for current year and all-time scope
- Uses sidekiq-scheduler gem for cron-like scheduling
- Rake tasks available for manual runs and initial population

**Decision: Automated nightly updates via Sidekiq**

## UI/UX Design

### Layout

```
Records Page
[Year Selector: 2026 ▼]

Temperature Records
┌──────────────────────────────────────────────────────────────────────────┐
│                          │  2026 (Jan 1 - present)  │  All Time          │
├──────────────────────────────────────────────────────────────────────────┤
│ Highest Temperature      │  95.3°F  Jul 15, 2026    │ 102.1°F Jul 8, 2024│
│ Lowest Temperature       │  18.2°F  Jan 3, 2026     │  12.8°F Dec 20, 2022│
│ ...                      │                          │                    │
└──────────────────────────────────────────────────────────────────────────┘

Wind Records
┌──────────────────────────────────────────────────────────────────────────┐
│                          │  2026 (Jan 1 - present)  │  All Time          │
│ ...                      │                          │                    │
└──────────────────────────────────────────────────────────────────────────┘

[continues for each category]
```

### Styling

- Use existing ViewComponent patterns
- Responsive table layout
- Section headers for categories
- Highlight all-time records when viewing yearly data

## Decisions Made

1. **Auto-update**: ✅ Sidekiq job running nightly at 12:02 AM America/Los_Angeles

2. **Lowest Solar Irradiance**: ✅ Dropped from records list

3. **Year Definition**: ✅ Calendar year (Jan-Dec). Current year shows Jan 1 to yesterday (incomplete data)

4. **Data Display**: ✅ Two columns - selected year and all-time

5. **ViewComponent Structure**: ✅ Sidecar pattern - template in subfolder

6. **Wind Run Calculation**: Sum wind_speed over 24-hour periods, converting m/s to miles

7. **Consecutive Days Logic**: Calendar days based on date portion of reading_date_time

## Implementation Order

1. ✅ Document architecture and plan
2. Create Record migration and model
3. Build RecordCalculator service (start with simple records, add complex ones)
4. Create Sidekiq job for nightly updates (with sidekiq-scheduler config)
5. Create controller and routes
6. Build RecordsTableComponent (with sidecar structure)
7. Add rake tasks for manual updates
8. Test with sample data
9. Add year selector UI
10. Polish and deploy

## Notes

- Records are scoped by year or all-time, stored in single table with scope enum
- Complex calculations (consecutive days, wind run, temp ranges) require daily aggregations first
- Component-based UI follows existing pattern (similar to ReportsController/Components)
- Can extend later with: monthly records, seasonal records, comparison views

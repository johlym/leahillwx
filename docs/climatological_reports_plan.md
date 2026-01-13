# Climatological Reports Implementation Plan

## Overview

Generate monthly climatological summary reports from WeatherMeasurement data, available in HTML and text formats. Reports run as a daily Sidekiq job at 12:01am America/Los_Angeles time.

## Data Specifications

### Source Data

- **Model**: `WeatherMeasurement`
- **Frequency**: Every 5 seconds when sender is active
- **Timezone**: America/Los_Angeles

### Report Calculations (Per Day)

#### Temperature

- **Mean Temp**: Average of all temperature readings for the day
- **High Temp**: Maximum temperature + time of occurrence
- **Low Temp**: Minimum temperature + time of occurrence

#### Degree Days

- **Base Temperature**: 65°F (18.3°C)
- **Heat Degree Days**: `max(0, 65 - mean_temp)` (when mean < 65°F)
- **Cool Degree Days**: `max(0, mean_temp - 65)` (when mean > 65°F)

#### Precipitation

- **Daily Rain**: Final `rain_day` value of the day (cumulative mm → convert to inches)

#### Wind

- **Average Wind Speed**: Mean of all `wind_speed` readings (convert mps → mph)
- **High Wind Speed**: Maximum `gust_speed` + time of occurrence (convert mps → mph)
- **Dominant Direction**: Calculated using vector averaging method (see technical notes)
  - Convert each wind observation to U/V components using wind speed and direction
  - Average all U components and V components separately
  - Use `atan2` to get resultant angle, convert to degrees (0-360°)
  - Format: `123 (SE)` - degrees with compass bearing in parentheses

## Report Formats

### Text Format

```
MONTHLY CLIMATOLOGICAL SUMMARY for [Month YYYY]

MONTHLY STATISTICS:
  Mean Temperature:     59.6°F
  High Temperature:     91.2°F (Day 14)
  Low Temperature:      41.2°F (Day 10)
  Heat Degree Days:     199.8
  Cool Degree Days:     31.9
  Total Precipitation:  1.11 in
  Avg Wind Speed:       0.5 mph
  High Wind Speed:      15.9 mph (Day 2)
  Dominant Wind Dir:    36° (NE)

                   TEMPERATURE (°F), RAIN (in), WIND SPEED (mph)

                                         HEAT   COOL         AVG
      MEAN                               DEG    DEG          WIND                   DOM
DAY   TEMP   HIGH   TIME    LOW   TIME   DAYS   DAYS   RAIN  SPEED   HIGH   TIME    DIR
---------------------------------------------------------------------------------------
 01   50.8   54.7  11:36   45.9  06:02   14.2    0.0   0.03    0.3    8.1  12:38   18 (N)
 02   58.2   71.8  17:28   48.7  03:50    6.8    0.0   0.03    0.7   15.9  02:15   19 (N)
...
 31   54.8   65.1  15:47   48.4  05:29   10.2    0.0   0.00    0.4    8.1  15:57   50 (NE)
---------------------------------------------------------------------------------------

Notes:
- Times shown in 24-hour format (HH:MM) America/Los_Angeles timezone
- Days with no data shown as "N/A"
- * Indicates partial day (incomplete measurements)
- Report generated in 0.42 seconds
```

### HTML Format

- Clean, modern table layout
- Responsive design
- Print-friendly stylesheet
- Same data as text format but styled

#### Navigation Menu

- **Year Dropdown**: Shows all years with available reports (descending order)
- **Month Dropdown**: Dynamically populated based on selected year (shows only months with reports for that year)
- **GO Button**: Navigates to `/reports/:year/:month_name`
- Default selection: Current year and most recent available month
- Uses Turbo/Stimulus for dynamic month filtering without page reload

## Database Schema

### `reports` table

Parent table for monthly reports:

- `year` (integer, indexed)
- `month` (integer, indexed)
- `month_mean_temp` (float)
- `month_high_temp` (float)
- `month_high_temp_day` (integer) - day of month
- `month_low_temp` (float)
- `month_low_temp_day` (integer) - day of month
- `total_heat_degree_days` (float)
- `total_cool_degree_days` (float)
- `total_rain` (float) - in inches
- `avg_wind_speed` (float) - in mph
- `month_high_wind_speed` (float) - in mph
- `month_high_wind_day` (integer) - day of month
- `dominant_wind_dir` (integer) - degrees
- `dominant_wind_dir_compass` (string)
- `created_at`, `updated_at`
- **Unique index on `[year, month]`**

### `report_entries` table

Child table - one entry per day:

- `report_id` (bigint, foreign key, indexed)
- `day` (integer) - day of month (1-31)
- `mean_temp` (float, nullable)
- `high_temp` (float, nullable)
- `high_temp_time` (string, nullable) - HH:MM in 24-hour format
- `low_temp` (float, nullable)
- `low_temp_time` (string, nullable) - HH:MM in 24-hour format
- `heat_degree_days` (float, nullable)
- `cool_degree_days` (float, nullable)
- `rain` (float, nullable) - in inches
- `avg_wind_speed` (float, nullable) - in mph
- `high_wind_speed` (float, nullable) - in mph
- `high_wind_time` (string, nullable) - HH:MM in 24-hour format
- `wind_dir` (integer, nullable) - degrees
- `wind_dir_compass` (string, nullable)
- `partial_day` (boolean, default: false) - indicates incomplete day of measurements
- `created_at`, `updated_at`
- **Unique index on `[report_id, day]`**
- **Foreign key with `dependent: :destroy` cascade**

### Relationship

```ruby
# Report has_many :entries, class_name: 'ReportEntry', dependent: :destroy
# ReportEntry belongs_to :report, class_name: 'Report'
```

## Architecture

### Service Objects

#### `WeatherData::DailyAggregator`

- Aggregates all WeatherMeasurement records for a specific date
- Calculates daily statistics using vector averaging for wind direction
- Determines if day is partial (< expected measurements for full day)
- Finds or creates parent `Report` for the month
- Creates/updates single `ReportEntry` for the day
- Sets `partial_day` flag if measurements incomplete
- Recalculates monthly statistics on parent report
- **Input**: Date
- **Output**: ReportEntry record
- **Edge Cases**:
  - No measurements: Creates entry with all NULL values
  - Partial measurements: Calculates stats but sets `partial_day: true`

#### `WeatherData::MonthlyStatsCalculator`

- Calculates monthly aggregate statistics from all entries
- **Monthly Avg Wind Speed**: Average of daily average wind speeds (average of averages)
- **Monthly Dominant Wind**: Vector averaging across all daily U/V components
- Updates parent `Report` with monthly totals/extremes
- Called automatically after each daily entry is created/updated
- **Input**: Report
- **Output**: Updated Report record

#### `WeatherData::ReportRenderer`

- Renders HTML and text views from a Report
- Generates formatted output for display
- **Partial Month Handling**: Shows only day number for future days, leaves data blank
- **Partial Day Indicator**: Appends asterisk (\*) to rows with incomplete data
- **Missing Day Handling**: Shows "N/A" for all columns when no measurements exist
- Adds footnote if any partial days exist
- Tracks and logs generation time
- **Input**: Report
- **Output**: Hash with `:html`, `:text`, and `:generation_time` keys

### Jobs

#### `GenerateReportJob`

- Scheduled via `sidekiq-cron` at 12:01am America/Los_Angeles daily
- Runs `DailyAggregator` for yesterday's date
- Creates/updates single entry for yesterday
- Monthly statistics automatically recalculated on parent report
- On the 1st of the month, also finalizes previous month's entry if missing
- Logs total processing time

**Sidekiq-Cron Configuration:**

```yaml
# config/schedule.yml
generate_report_job:
  cron: "1 0 * * * America/Los_Angeles"
  class: "GenerateReportJob"
```

### Routes & Controllers

```ruby
# Routes
GET /reports
  # Index page with navigation menu
  # Redirects to most recent report if available

GET /reports/available.json
  # Returns JSON of available reports grouped by year
  # Format: { "2023" => ["january", "february", ...], "2024" => [...] }
  # Used by navigation menu for dynamic month filtering

GET /reports/:year/:month_name
  # e.g., /reports/2023/may or /reports/2023/may.txt
  # Defaults to HTML
  # Use .txt extension for text format

# Controller: ReportsController
# Actions:
#   - index
#       Shows navigation menu, redirects to latest report if exists
#       If no reports: Shows dropdowns with "Select a Year and Month" message
#   - available
#       Returns JSON of year => months mapping
#       Returns empty hash if no reports exist
#   - show (year, month_name params)
#       Finds Report with entries (eager loaded)
#       Renders using ReportRenderer
#       Responds with HTML or text based on format
#       Displays "Report generated in N.NN seconds" at bottom
#       Includes navigation menu at top
#       Shows 404 if report not found
```

## Implementation Order

1. **Database Setup**

   - Add index to `weather_measurements.reading_date_time` (currently missing)
   - Create migrations for `reports` and `report_entries` tables
   - Add indexes and foreign key constraints with cascade delete

2. **Models**

   - `Report` model with validations and `dependent: :destroy` association
   - `ReportEntry` model with validations, nullable fields for missing/partial data
   - Add helper methods for vector averaging calculations
   - Add concern for unit conversions (C→F, mm→in, mps→mph)

3. **Service Layer**

   - `WeatherData::DailyAggregator` service
   - `WeatherData::MonthlyStatsCalculator` service
   - `WeatherData::ReportRenderer` service
   - Helper methods for unit conversions and calculations

4. **View Templates**

   - Navigation menu partial (HTML only) with year/month dropdowns
   - Stimulus controller for dynamic month filtering
   - Text template (ERB) with monthly stats header
   - HTML template with modern styling, navigation menu, and monthly stats card

5. **Background Job**

   - `GenerateReportJob` (fixed from ClimatologicalReportJob typo)
   - sidekiq-cron configuration in `config/schedule.yml`

6. **Controller & Routes**

   - `ReportsController#show`
   - Route definitions
   - Handle 404 for missing reports

7. **Rake Tasks**

   - `rake reports:backfill[start_date,end_date]` - Backfill historical reports
     - **Default**: If no dates provided, backfills Dec 2021 → yesterday
   - `rake reports:purge[year,month]` - Delete report (cascade deletes entries) and regenerate
   - `rake reports:purge_all` - Delete all reports (with confirmation)

8. **Testing**
   - Model tests
   - Service tests
   - Controller tests
   - Job tests
   - Rake task tests

## Decisions Made

✅ **Report Generation**: Option A - Daily job creates/updates single entry, monthly stats auto-calculated  
✅ **Missing Data**: Display as "N/A" in reports  
✅ **Time Format**: HH:MM in 24-hour format (America/Los_Angeles)  
✅ **Degree Days**: Standard 65°F base  
✅ **Dominant Direction**: Show degrees with compass in parentheses, e.g., "36 (NE)"  
✅ **Rain Calculation**: Use final `rain_day` value of each day  
✅ **Report Storage**: Database-backed, routes `/reports/$year/$month_name`  
✅ **Job System**: Sidekiq job at 12:01am daily  
✅ **Rake Tasks**: Backfill and purge tasks included  
✅ **Monthly Summary**: Display at TOP of report, not bottom  
✅ **Scope**: Each month isolated, no cross-month comparisons  
✅ **Model Names**: `Report` and `ReportEntry` (not Climatological\*)  
✅ **Performance Logging**: Display "Report generated in N.NN seconds" at bottom  
✅ **Data Retention**: Raw WeatherMeasurement records kept forever, never deleted/archived  
✅ **Historical Data**: Available from December 2021 onwards  
✅ **Indexing**: Single index on `reading_date_time` for now (Option 1)  
✅ **HTML Navigation**: Year/month dropdown menu for report navigation

## Implementation Details - Edge Cases & Clarifications

### Missing Data Handling

1. **Entire Day Missing** (sensor down, no measurements)

   - Create `ReportEntry` with day number and all NULL values
   - Display as "N/A" in all data columns
   - `partial_day` flag = false

2. **Partial Day** (some measurements but not full day)

   - Calculate statistics from available measurements
   - Set `partial_day` flag = true
   - Display asterisk (\*) at end of row
   - Add footnote: "\* Indicates partial day (incomplete measurements)"

3. **Current/Incomplete Month**
   - Only show day numbers for future days
   - Leave all data columns blank (not N/A, just empty)
   - No asterisk for future days

### Wind Direction Calculations

**Vector Averaging Method** (see `/docs/dominant_wind_direction.md`):

```ruby
# For each measurement with wind_speed (WS) and wind_dir (WD):
U = WS * Math.sin(WD * Math::PI / 180)  # East-West component
V = WS * Math.cos(WD * Math::PI / 180)  # North-South component

# Average all U and V components:
U_avg = U_values.sum / U_values.count
V_avg = V_values.sum / V_values.count

# Calculate resultant direction:
angle_rad = Math.atan2(U_avg, V_avg)
angle_deg = angle_rad * 180 / Math::PI
angle_deg += 360 if angle_deg < 0  # Normalize to 0-360°
```

### Database Constraints

- `reports`: Unique index on `[year, month]` prevents duplicates
- `report_entries`: Unique index on `[report_id, day]` prevents duplicates
- Foreign key with `ON DELETE CASCADE` ensures cleanup when report deleted
- All data fields nullable to support missing/partial days

### Rake Task Defaults

```bash
# Backfill everything from Dec 2021 to yesterday
rake reports:backfill

# Backfill specific range
rake reports:backfill[2023-01-01,2023-12-31]

# Purge and regenerate specific month
rake reports:purge[2023,5]  # May 2023

# Nuclear option: delete all reports (asks for confirmation)
rake reports:purge_all
```

### Sidekiq-Cron Setup

```ruby
# config/schedule.yml
generate_report_job:
  cron: "1 0 * * * America/Los_Angeles"  # 12:01am daily
  class: "GenerateReportJob"
  description: "Generate daily climatological report entry"
```

## Performance Considerations - Separate Discussion

### `weather_measurements` Table Indexing Strategy

**Current Situation:**

- ~17,280 records per day (every 5 seconds)
- ~518,400 records per month
- ~6.2M records per year

**Key Query Patterns:**

1. **Daily Aggregation** (12:01am job):

   ```sql
   SELECT * FROM weather_measurements
   WHERE reading_date_time >= '2023-05-01 00:00:00'
     AND reading_date_time < '2023-05-02 00:00:00'
   ORDER BY reading_date_time ASC
   ```

2. **Finding High/Low with Time**:

   ```sql
   SELECT MAX(temperature), reading_date_time FROM weather_measurements
   WHERE reading_date_time BETWEEN ... GROUP BY ...
   ```

3. **Most Recent Reading** (for current weather display):
   ```sql
   SELECT * FROM weather_measurements
   ORDER BY reading_date_time DESC LIMIT 1
   ```

**Recommended Indexes:**

```ruby
# In migration
add_index :weather_measurements, :reading_date_time
add_index :weather_measurements, [:reading_date_time, :temperature]
add_index :weather_measurements, [:reading_date_time, :gust_speed]
```

**Discussion Points:**

1. **Single vs Composite Indexes**

   - Single index on `reading_date_time` covers most queries
   - Composite indexes help with aggregation queries but increase write overhead
   - Trade-off: Faster reads vs slower writes (one write every 5 seconds)

2. **Partitioning Strategy** (Future)

   - Consider table partitioning by month/year after 1-2 years of data
   - PostgreSQL supports native partitioning
   - Keeps active queries fast while archiving old data

3. **Retention Policy**

   - ✅ **DECIDED**: Raw measurements kept forever - NEVER delete/archive/modify
   - Reports generated from historical data going back to December 2021

4. **Query Optimization**
   - Use `pluck` instead of loading full ActiveRecord objects for aggregations
   - Consider `select` with only needed columns
   - Use `find_in_batches` for large date ranges

**Decisions:**

- ✅ Single `reading_date_time` index (Option 1)
- ✅ Raw measurements retained forever - NEVER delete/archive
- ✅ Historical data available from December 2021
- ✅ Performance tracking via "Report generated in N.NN seconds" footer

## Next Steps

1. ✅ Finalize plan document with user decisions
2. 🔄 Discuss and finalize indexing strategy
3. ⏭️ Begin implementation with migrations
4. ⏭️ Create models and associations
5. ⏭️ Implement service layer
6. ⏭️ Build views and controller
7. ⏭️ Add Sidekiq job and scheduling
8. ⏭️ Create rake tasks
9. ⏭️ Write tests

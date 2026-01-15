# RecordCalculator Parallelization & Optimization Options

## Current Performance Bottlenecks

The `RecordCalculator` currently runs 6 calculation methods sequentially:

1. `calculate_temperature_records` - 10 database queries
2. `calculate_wind_records` - 4+ queries (includes sequential calm period analysis)
3. `calculate_rain_records` - 5+ queries (includes sequential rain day analysis)
4. `calculate_humidity_records` - 4 queries
5. `calculate_barometer_records` - 3 queries
6. `calculate_sun_records` - 1 query

**Total: ~27+ database queries per record (yearly or all-time)**

## Parallelization Options

### Option 1: Ruby Parallel Gem ⭐ RECOMMENDED

**Complexity:** Low | **Performance Gain:** 3-5x | **Safety:** High

Use the `parallel` gem to run independent calculation methods in parallel threads.

```ruby
# Add to Gemfile
gem 'parallel', '~> 1.24'

# In RecordCalculator
def calculate_and_save!
  Parallel.each([
    :calculate_temperature_records,
    :calculate_wind_records,
    :calculate_rain_records,
    :calculate_humidity_records,
    :calculate_barometer_records,
    :calculate_sun_records
  ], in_threads: 6) do |method_name|
    send(method_name)
  end

  @record.save!
  @record
end
```

**Pros:**

- Simple implementation, minimal code changes
- Thread-safe with Rails (each thread gets its own DB connection)
- Can control thread count
- Works well for I/O-bound operations (DB queries)

**Cons:**

- Ruby GIL limits true parallelism (but DB queries are I/O, so this still helps)
- Requires `parallel` gem dependency

---

### Option 2: Concurrent-Ruby Promises

**Complexity:** Medium | **Performance Gain:** 3-5x | **Safety:** High

Use concurrent-ruby (already a Rails dependency) for promise-based parallelization.

```ruby
require 'concurrent'

def calculate_and_save!
  promises = [
    Concurrent::Promise.execute { calculate_temperature_records },
    Concurrent::Promise.execute { calculate_wind_records },
    Concurrent::Promise.execute { calculate_rain_records },
    Concurrent::Promise.execute { calculate_humidity_records },
    Concurrent::Promise.execute { calculate_barometer_records },
    Concurrent::Promise.execute { calculate_sun_records }
  ]

  # Wait for all to complete
  Concurrent::Promise.zip(*promises).value!

  @record.save!
  @record
end
```

**Pros:**

- No additional gem required (concurrent-ruby is a Rails dependency)
- Modern promise-based API
- Good error handling

**Cons:**

- More verbose than Option 1
- Requires understanding of promise/future concepts

---

### Option 3: Database Query Optimization (Single-Pass Aggregation)

**Complexity:** High | **Performance Gain:** 5-10x | **Safety:** High

Rewrite calculations to use a single large SQL query with CTEs (Common Table Expressions) that calculates all records in one pass.

```ruby
def calculate_all_records_optimized
  sql = <<-SQL
    WITH daily_stats AS (
      SELECT
        DATE(reading_date_time) as date,
        MAX(temperature) as max_temp,
        MIN(temperature) as min_temp,
        MAX(temperature) - MIN(temperature) as temp_range,
        MAX(gust_speed) as max_gust,
        -- ... more aggregations
      FROM weather_measurements
      WHERE #{scope_condition}
      GROUP BY DATE(reading_date_time)
    ),
    instant_records AS (
      SELECT
        temperature,
        reading_date_time,
        -- ... all fields we need for instant records
      FROM weather_measurements
      WHERE #{scope_condition}
    )
    -- Complex query combining CTEs
  SQL

  # Parse results and populate @record
end
```

**Pros:**

- Massive performance improvement (one DB round-trip vs 27+)
- Scales well with large datasets
- Database does the heavy lifting

**Cons:**

- Very complex SQL, harder to maintain
- Database-specific (PostgreSQL)
- Harder to debug
- Requires significant refactoring

---

### Option 4: Sidekiq Batch Jobs (Parallel Workers)

**Complexity:** Medium | **Performance Gain:** 2-4x | **Safety:** Medium

Split calculations across multiple Sidekiq workers.

```ruby
# Create separate jobs for each category
class CalculateTemperatureRecordsJob
  include Sidekiq::Job
  def perform(record_id)
    record = Record.find(record_id)
    calculator = RecordCalculator.new(scope: record.scope, year: record.year)
    calculator.calculate_temperature_records
    record.save!
  end
end

# In main job
def perform
  record = Record.find_or_create_by(scope: "all_time")

  batch = Sidekiq::Batch.new
  batch.on(:success, self.class, 'record_id' => record.id)
  batch.jobs do
    CalculateTemperatureRecordsJob.perform_async(record.id)
    CalculateWindRecordsJob.perform_async(record.id)
    # ... etc
  end
end
```

**Pros:**

- Can leverage multiple servers/processes
- Good for distributed systems
- Built-in retry logic

**Cons:**

- Requires Sidekiq Pro for batches (paid)
- More complex job coordination
- Potential race conditions on record updates
- Overkill for this use case

---

### Option 5: Hybrid Approach - Optimize + Parallelize ⭐ BEST LONG-TERM

**Complexity:** High | **Performance Gain:** 10-20x | **Safety:** High

Combine database optimization with parallelization for best results.

**Phase 1:** Optimize individual queries

- Use `pluck` instead of loading full ActiveRecord objects where possible
- Add database indexes on `reading_date_time`, `temperature`, etc.
- Cache the `measurements` relation to avoid re-filtering

**Phase 2:** Parallelize independent operations

- Use Parallel gem for the 6 main categories
- Keep complex sequential logic (consecutive days, calm periods) in single threads

```ruby
def calculate_and_save!
  # Cache measurements query to avoid repeated WHERE clauses
  @cached_measurements = measurements.to_a

  Parallel.each([
    :calculate_temperature_records,
    :calculate_wind_records,
    :calculate_rain_records,
    :calculate_humidity_records,
    :calculate_barometer_records,
    :calculate_sun_records
  ], in_threads: 6) do |method_name|
    send(method_name)
  end

  @record.save!
  @record
end

private

def measurements
  @measurements ||= begin
    base = WeatherMeasurement.select(
      :id, :reading_date_time, :temperature, :humidity,
      :gust_speed, :wind_speed, :rain_day, :rain_rate,
      :barometer_rel, :light
    )
    # ... existing filtering logic
  end
end
```

**Pros:**

- Best of both worlds - fast queries AND parallel execution
- Incremental implementation (can optimize one category at a time)
- Maintainable

**Cons:**

- Takes more development time
- Requires careful testing

---

## Recommendation Matrix

| Use Case                                | Recommended Option            | Expected Speedup |
| --------------------------------------- | ----------------------------- | ---------------- |
| Quick win, minimal changes              | **Option 1: Parallel Gem**    | 3-5x             |
| Already have concurrent-ruby experience | Option 2: Concurrent Promises | 3-5x             |
| Large dataset (millions of records)     | **Option 5: Hybrid**          | 10-20x           |
| Long-term production optimization       | **Option 5: Hybrid**          | 10-20x           |
| Have Sidekiq Pro license                | Option 4: Sidekiq Batch       | 2-4x             |

## Immediate Action Plan

### Quick Win (1-2 hours):

1. Implement **Option 1 (Parallel Gem)**
2. Add database indexes:
   ```sql
   CREATE INDEX idx_weather_temp ON weather_measurements(temperature);
   CREATE INDEX idx_weather_humidity ON weather_measurements(humidity);
   CREATE INDEX idx_weather_pressure ON weather_measurements(barometer_rel);
   ```
3. Measure improvement

### Long-term Optimization (1-2 days):

1. Profile individual calculation methods
2. Optimize slowest queries first
3. Implement selective field loading (`.select()`)
4. Consider caching measurements in memory for sequential analysis

## Benchmarking Recommendations

Test with your actual data to measure improvements:

```ruby
require 'benchmark'

Benchmark.bm do |x|
  x.report("Sequential:") do
    RecordCalculator.new(scope: "all_time").calculate_and_save!
  end

  x.report("Parallel:") do
    RecordCalculatorParallel.new(scope: "all_time").calculate_and_save!
  end
end
```

## Database Indexes to Add

```ruby
# migration
class AddIndexesForRecordCalculation < ActiveRecord::Migration[8.1]
  def change
    add_index :weather_measurements, :temperature
    add_index :weather_measurements, :humidity
    add_index :weather_measurements, :gust_speed
    add_index :weather_measurements, :barometer_rel
    add_index :weather_measurements, :light
    add_index :weather_measurements, [:reading_date_time, :rain_day]
  end
end
```

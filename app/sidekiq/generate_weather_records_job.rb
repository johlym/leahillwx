# DEPRECATED: Split into GenerateYearRecordsJob and GenerateAllTimeRecordsJob
# This job is kept for backwards compatibility but is no longer scheduled
class GenerateWeatherRecordsJob
  include Sidekiq::Job

  def perform
    Rails.logger.warn "DEPRECATED: GenerateWeatherRecordsJob is deprecated. Use GenerateYearRecordsJob and GenerateAllTimeRecordsJob instead."

    current_year = Time.current.year

    Rails.logger.info "Calculating records for year #{current_year}"
    RecordCalculator.new(scope: "yearly", year: current_year).calculate_and_save!

    Rails.logger.info "Calculating all-time records"
    RecordCalculator.new(scope: "all_time").calculate_and_save!

    Rails.logger.info "Weather records calculation complete"
  end
end

class GenerateAllTimeRecordsJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Starting all-time records calculation"
    RecordCalculator.new(scope: "all_time").calculate_and_save!
    Rails.logger.info "✓ All-time records calculation complete"
  end
end

class GenerateYearRecordsJob
  include Sidekiq::Job

  def perform(year = nil)
    year ||= Time.current.year

    Rails.logger.info "Starting records calculation for year #{year}"
    RecordCalculator.new(scope: "yearly", year: year).calculate_and_save!
    Rails.logger.info "✓ Year #{year} records calculation complete"
  end
end

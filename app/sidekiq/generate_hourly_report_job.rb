class GenerateHourlyReportJob
  include Sidekiq::Worker

  def perform(datetime = nil)
    # Default to the previous hour if no datetime provided, in Pacific time
    target_datetime = if datetime
      Time.parse(datetime.to_s).in_time_zone("America/Los_Angeles")
    else
      1.hour.ago.in_time_zone("America/Los_Angeles")
    end

    Rails.logger.info "GenerateHourlyReportJob: Processing datetime #{target_datetime}"

    start_time = Time.current

    begin
      aggregator = WeatherData::HourlyAggregator.new(target_datetime)
      entry = aggregator.aggregate

      processing_time = (Time.current - start_time).round(2)

      Rails.logger.info "GenerateHourlyReportJob: Successfully created/updated hourly entry"
      Rails.logger.info "  - Date: #{entry.day}"
      Rails.logger.info "  - Hour: #{entry.hour}"
      Rails.logger.info "  - Mean temp: #{entry.mean_temp&.round(2)}°C"
      Rails.logger.info "  - Partial hour: #{entry.partial_period}"
      Rails.logger.info "  - Processing time: #{processing_time} seconds"

    rescue StandardError => e
      Rails.logger.error "GenerateHourlyReportJob: Error processing #{target_datetime}"
      Rails.logger.error "  - #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end
end

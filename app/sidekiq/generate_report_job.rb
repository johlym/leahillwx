class GenerateReportJob
  include Sidekiq::Job

  def perform(date = nil)
    # Default to yesterday if no date provided
    target_date = date ? Date.parse(date.to_s) : Date.yesterday

    Rails.logger.info "GenerateReportJob: Processing date #{target_date}"

    start_time = Time.current

    begin
      aggregator = WeatherData::DailyAggregator.new(target_date)
      entry = aggregator.aggregate

      processing_time = (Time.current - start_time).round(2)

      Rails.logger.info "GenerateReportJob: Successfully created/updated entry for #{target_date}"
      Rails.logger.info "  - Day: #{entry.day}"
      Rails.logger.info "  - Mean temp: #{entry.mean_temp&.round(2)}°F"
      Rails.logger.info "  - Partial day: #{entry.partial_period}"
      Rails.logger.info "  - Processing time: #{processing_time} seconds"

      # On the 1st of the month, also finalize previous month if missing last day
      if target_date.day == 1
        previous_month = target_date - 1.day
        finalize_previous_month(previous_month)
      end

    rescue StandardError => e
      Rails.logger.error "GenerateReportJob: Error processing #{target_date}"
      Rails.logger.error "  - #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  private

  def finalize_previous_month(date)
    Rails.logger.info "GenerateReportJob: Finalizing previous month (#{date.strftime('%B %Y')})"

    report = Report.find_by(year: date.year, month: date.month)
    return unless report

    last_day = Date.new(date.year, date.month, -1).day
    existing_entry = report.entries.find_by(day: last_day)

    if existing_entry
      Rails.logger.info "  - Last day entry already exists"
    else
      Rails.logger.info "  - Creating last day entry for day #{last_day}"
      aggregator = WeatherData::DailyAggregator.new(date)
      aggregator.aggregate
    end
  end
end

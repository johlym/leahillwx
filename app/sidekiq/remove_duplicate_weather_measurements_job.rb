class RemoveDuplicateWeatherMeasurementsJob
  include Sidekiq::Job

  def perform(*args)
    duplicate_date_times = WeatherMeasurement
      .group(:reading_date_time)
      .having("COUNT(*) > 1")
      .pluck(:reading_date_time)

    Rails.logger.info("Duplicate entries found: #{duplicate_date_times.count}")

    count = duplicate_date_times.count
    counter = 0

    duplicate_date_times.each do |date_time|
      counter += 1
      Rails.logger.info("#{counter}/#{count} Removing duplicates for #{date_time}")
      records = WeatherMeasurement.where(reading_date_time: date_time).order(:id)
      records_to_delete = records.offset(1)
      records_to_delete.destroy_all
    end

    Rails.logger.info("Duplicate entries removed: #{duplicate_date_times.count}")
  end
end

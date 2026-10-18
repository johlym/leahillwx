class RecalculateMeasurementTotalCountJob
  include Sidekiq::Job

  def perform(*_args)
    WeatherMeasurements::TotalCount.recalculate!
  end
end

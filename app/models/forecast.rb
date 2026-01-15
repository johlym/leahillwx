# The Forecast model represents a forecast from the OpenWeather API.
# A Sidekiq job retrieves the forecast from the OpenWeather API every 10 minutes.
# The Forecast model has only one column: forecast (JSON)
#
# A separate job ("DeleteOldForecastsJob") is scheduled to run daily to delete forecasts older than 7 days.
# == Schema Information
#
# Table name: forecasts
#
#  id         :bigint           not null, primary key
#  forecast   :jsonb
#  interval   :string           default("daily"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# EXAMPLE FORECAST DATA OBJECT: see `docs/example_forecast.json`
class Forecast < ApplicationRecord
  validates :forecast, presence: true
end

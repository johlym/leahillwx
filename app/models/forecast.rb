# The Forecast model represents a forecast from the OpenWeather API.
# A Sidekiq job retrieves the forecast from the OpenWeather API every 10 minutes.
# The Forecast model has only one column: forecast (JSON)
class Forecast < ApplicationRecord
  validates :forecast, presence: true
end

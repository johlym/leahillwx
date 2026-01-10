# The Forecast model represents a forecast from the OpenWeather API.
# A Sidekiq job retrieves the forecast from the OpenWeather API every 10 minutes.
# The Forecast model has only one column: forecast (JSON)
# == Schema Information
#
# Table name: forecasts
#
#  id         :bigint           not null, primary key
#  forecast   :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Forecast < ApplicationRecord
  validates :forecast, presence: true
end

class WeatherMeasurementsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "weather_measurements"
  end

  def unsubscribed
  end
end

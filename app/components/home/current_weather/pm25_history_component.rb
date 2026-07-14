# frozen_string_literal: true

class Home::CurrentWeather::Pm25HistoryComponent < ViewComponent::Base
  def initialize(history: [])
    @history = Array(history)
  end

  def render?
    @history.any?
  end

  def chart_payload
    labels = @history.map { |row| row.observed_at.in_time_zone("America/Los_Angeles").strftime("%-I%p") }
    values = @history.map(&:pm2_5)

    {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "PM2.5",
            key: "pm25",
            data: values,
            color: "rgb(255, 126, 0)"
          }
        ]
      },
      options: {
        yUnit: " µg/m³",
        yDecimals: 1
      }
    }
  end
end

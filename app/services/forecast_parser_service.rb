class ForecastParserService
  def initialize(forecast)
    @raw_forecast = forecast
    @forecast_data = if forecast.nil?
      nil
    elsif forecast.is_a?(Hash)
      forecast
    else
      forecast.forecast
    end
  end

  def parse
    return nil if @forecast_data.nil?

    created_at = @raw_forecast.respond_to?(:created_at) ? @raw_forecast.created_at : nil
    ParsedForecast.new(@forecast_data, created_at: created_at)
  end

  class ParsedForecast
    attr_reader :lat, :lon, :timezone, :timezone_offset, :alerts, :created_at

    def initialize(data, created_at: nil)
      @data = data.deep_symbolize_keys
      @created_at = created_at
      @lat = @data[:lat]
      @lon = @data[:lon]
      @timezone = @data[:timezone]
      @timezone_offset = @data[:timezone_offset]
      @alerts = @data[:alerts] || []
      @days = (@data[:daily] || []).map { |day_data| ForecastDay.new(day_data) }
    end

    def today
      @days[0]
    end

    def tomorrow
      @days[1]
    end

    def day(index)
      @days[index]
    end

    def days
      @days
    end

    # Dynamic day accessors: day_0 through day_7
    (0..7).each do |i|
      define_method("day_#{i}") { @days[i] }
    end
  end

  class ForecastDay
    DIRECT_ATTRS = %i[
      dt sunrise sunset moonrise moonset moon_phase summary
      pressure humidity dew_point wind_deg
      clouds pop rain snow uvi
    ].freeze

    def initialize(data)
      @data = data.deep_symbolize_keys
    end

    DIRECT_ATTRS.each do |attr|
      define_method(attr) { @data[attr] }
    end

    # Temperature accessors
    def temp
      @data[:temp]
    end

    def temp_day
      celsius_to_fahrenheit(@data.dig(:temp, :day))
    end

    def temp_min
      celsius_to_fahrenheit(@data.dig(:temp, :min))
    end

    def temp_max
      celsius_to_fahrenheit(@data.dig(:temp, :max))
    end

    def temp_night
      celsius_to_fahrenheit(@data.dig(:temp, :night))
    end

    def temp_eve
      celsius_to_fahrenheit(@data.dig(:temp, :eve))
    end

    def temp_morn
      celsius_to_fahrenheit(@data.dig(:temp, :morn))
    end

    # Wind accessors (converted to mph)
    def wind_speed
      ms_to_mph(@data[:wind_speed])
    end

    def wind_gust
      ms_to_mph(@data[:wind_gust])
    end

    # Feels like accessors
    def feels_like
      @data[:feels_like]
    end

    def feels_like_day
      celsius_to_fahrenheit(@data.dig(:feels_like, :day))
    end

    def feels_like_night
      celsius_to_fahrenheit(@data.dig(:feels_like, :night))
    end

    def feels_like_eve
      celsius_to_fahrenheit(@data.dig(:feels_like, :eve))
    end

    def feels_like_morn
      celsius_to_fahrenheit(@data.dig(:feels_like, :morn))
    end

    # Weather condition accessors
    def weather
      @data[:weather]&.first
    end

    def weather_id
      weather&.dig(:id)
    end

    def weather_main
      weather&.dig(:main)
    end

    def weather_description
      weather&.dig(:description)
    end

    def weather_icon
      weather&.dig(:icon)
    end

    # Time helpers
    def date
      Time.at(dt).to_date if dt
    end

    def sunrise_time
      Time.at(sunrise) if sunrise
    end

    def sunset_time
      Time.at(sunset) if sunset
    end

    private

    def celsius_to_fahrenheit(celsius)
      return nil if celsius.nil?
      (celsius * 9.0 / 5.0) + 32
    end

    def ms_to_mph(ms)
      return nil if ms.nil?
      ms * 2.23694
    end
  end
end

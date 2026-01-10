class ForecastParserService
  def initialize(forecast)
    @forecast = forecast.is_a?(Hash) ? forecast : forecast.forecast
  end

  def parse
    ParsedForecast.new(@forecast)
  end

  class ParsedForecast
    attr_reader :lat, :lon, :timezone, :timezone_offset, :alerts

    def initialize(data)
      @data = data.deep_symbolize_keys
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
      pressure humidity dew_point wind_speed wind_deg wind_gust
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
      @data.dig(:temp, :day)
    end

    def temp_min
      @data.dig(:temp, :min)
    end

    def temp_max
      @data.dig(:temp, :max)
    end

    def temp_night
      @data.dig(:temp, :night)
    end

    def temp_eve
      @data.dig(:temp, :eve)
    end

    def temp_morn
      @data.dig(:temp, :morn)
    end

    # Feels like accessors
    def feels_like
      @data[:feels_like]
    end

    def feels_like_day
      @data.dig(:feels_like, :day)
    end

    def feels_like_night
      @data.dig(:feels_like, :night)
    end

    def feels_like_eve
      @data.dig(:feels_like, :eve)
    end

    def feels_like_morn
      @data.dig(:feels_like, :morn)
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
  end
end

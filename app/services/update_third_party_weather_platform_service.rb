class UpdateThirdPartyWeatherPlatformService
  SUPPORTED_SERVICES = [
    "weatherunderground",
    "pwsweather",
    "awekas",
    "weathercloud",
    "cwop"
  ].freeze

  def initialize(weather_measurement, service)
    @weather_measurement = weather_measurement
    @service = service

    raise ArgumentError, "Unsupported service: #{@service}" unless SUPPORTED_SERVICES.include?(@service)
  end

  def perform
    Rails.logger.info "Updating third party weather platform: #{@service}"

    send("update_#{@service}", @weather_measurement)

    Rails.logger.info "Update complete for: #{@service}"
  end

  def update_weatherunderground(measurement)
  end

  def update_pwsweather(measurement)
  end

  def update_awekas(measurement)
  end

  def weathercloud(measurement)
  end

  def cwop(measurement)
  end
end

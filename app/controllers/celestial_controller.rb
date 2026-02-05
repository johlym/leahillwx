class CelestialController < ApplicationController
  before_action :authorize_host, if: -> { Rails.env.production? }
  before_action :validate_datestamp_params

  def sun
    render json: Celestial::EphemerisService.generate(:sun, datestamp_params)
  end

  def moon
    render json: Celestial::EphemerisService.generate(:moon, datestamp_params)
  end

  private

  def authorize_host
    allowed_hosts = Rails.application.config.hosts
    request_host = request.host

    # Check if host matches any allowed pattern
    is_allowed = allowed_hosts.any? do |host|
      case host
      when String
        host == request_host
      when Regexp
        host.match?(request_host)
      else
        false
      end
    end

    unless is_allowed
      render json: { error: "Unauthorized host" }, status: :forbidden
      nil
    end
  end

  def datestamp_params
    @datestamp_params ||= params.permit(:year, :month, :day)
  end

  def validate_datestamp_params
    unless datestamp_params[:year].present? && datestamp_params[:month].present? && datestamp_params[:day].present?
      render json: { error: "Invalid parameters: year, month, day must be present" }, status: :bad_request
    end
  end
end

class ApiController < ApplicationController
  skip_forgery_protection
  private

  def authenticate
    authenticate_or_request_with_http_token do |token, _options|
      ActiveSupport::SecurityUtils.secure_compare(token, ENV["MEASUREMENT_API_KEY"].to_s)
    end
  end
end

class ApiController < ApplicationController
  skip_forgery_protection
  private

  def authenticate
    api_key = ENV["MEASUREMENT_API_KEY"].to_s
    return head(:unauthorized) if api_key.blank?

    authenticate_or_request_with_http_token do |token, _options|
      ActiveSupport::SecurityUtils.secure_compare(token, api_key)
    end
  end
end

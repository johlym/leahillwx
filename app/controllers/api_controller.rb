class ApiController < ApplicationController
  skip_forgery_protection

  private

  def authenticate
    api_key = ENV["MEASUREMENT_API_KEY"].to_s
    return head(:unauthorized) if api_key.blank?

    authenticate_or_request_with_http_token do |token, _options|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(token),
        ::Digest::SHA256.hexdigest(api_key)
      )
    end
  end
end

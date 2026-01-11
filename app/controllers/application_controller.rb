class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_cache_headers, if: -> { Rails.env.production? }

  private

  def set_cache_headers
    response.headers["Cache-Control"] = "no-cache, private"
    response.headers["ETag"] = Rails.application.config.boot_etag
  end
end

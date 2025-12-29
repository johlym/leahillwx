class ApiController < ApplicationController
  skip_forgery_protection
  private

  def authenticate
    if ActiveSupport::SecurityUtils.secure_compare(request.headers["X-Api-Key"].to_s, ENV["MEASUREMENT_API_KEY"].to_s)
      return
    end

    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end

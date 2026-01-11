require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  root "root#index"
  get "about", to: "root#about"

  namespace :api do
    namespace :v1 do
      post :weather_measurement, to: "weather_measurements#create"
      post "weather_measurement/bulk", to: "weather_measurements#bulk_create"
    end
  end

  mount OasRails::Engine => "/docs"

  # basic auth for sidekiq dashboard
  if Rails.env.production? && ENV["SIDEKIQ_USER"] && ENV["SIDEKIQ_PASSWORD"]
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USER"])) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
    end
  end
  mount Sidekiq::Web => "/sidekiq"


  get "up" => "rails/health#show", as: :rails_health_check
end

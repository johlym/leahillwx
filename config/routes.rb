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

  # Reports routes
  get "reports", to: "reports#index", as: :reports
  get "reports/available", to: "reports#available", as: :available_reports
  get "reports/:year/:month_name", to: "reports#show", as: :report
  get "reports/:year/:month_name/:day", to: "reports#show_day", as: :report_day

  # Records routes
  get "records", to: "records#index", as: :records
  get "records/:year", to: "records#index", as: :records_year

  # Almanac routes
  get "almanac", to: "almanac#index", as: :almanac
  get "almanac/available", to: "almanac#available", as: :available_almanac
  get "almanac/:year/:month_name/:day", to: "almanac#show", as: :almanac_day

  get "up" => "rails/health#show", as: :rails_health_check
end

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  root "root#index"
  get "about", to: "root#about"
  get "alerts/bar", to: "alerts#bar", as: :alerts_bar
  get "alerts", to: "alerts#index", as: :alerts

  namespace :api do
    namespace :v1 do
      post :weather_measurement, to: "weather_measurements#create"
      post "weather_measurement/bulk", to: "weather_measurements#bulk_create"
    end
  end

  mount OasRails::Engine => "/docs"

  # Sidekiq dashboard: open in development; elsewhere only when credentials are configured.
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  elsif ENV["SIDEKIQ_USER"].present? && ENV["SIDEKIQ_PASSWORD"].present?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USER"])) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
    end
    mount Sidekiq::Web => "/sidekiq"
  end

  # Reports routes
  get "reports", to: "reports#index", as: :reports
  get "reports/available", to: "reports#available", as: :available_reports
  get "reports/:year/:month_name", to: "reports#show", as: :report
  get "reports/:year/:month_name/:day", to: "reports#show_day", as: :report_day

  # Records routes
  get "records", to: "records#index", as: :records
  get "records/:year", to: "records#index", as: :records_year, constraints: { year: /\d{4}/ }
  get "records/:year/:month_name", to: "records#index", as: :records_month, constraints: { year: /\d{4}/ }

  # Graphs routes
  get "graphs", to: "graphs#index", as: :graphs
  get "graphs/available", to: "graphs#available", as: :available_graphs
  get "graphs/:year/:month_name", to: "graphs#show", as: :graph
  get "graphs/:year/:month_name/:day", to: "graphs#show", as: :graph_day

  # Trends routes
  get "trends", to: "trends#index", as: :trends
  get "trends/:year", to: "trends#show", as: :trends_year, constraints: { year: /\d{4}/ }

  # Almanac routes
  get "almanac", to: "almanac#index", as: :almanac
  get "almanac/available", to: "almanac#available", as: :available_almanac
  get "almanac/:year/:month_name", to: "almanac#show", as: :almanac_month

  # Radar (full-viewport live map)
  get "radar", to: "radar#index", as: :radar

  # Celestial routes (ephemeris API)
  get "celestial/sun", to: "celestial#sun"
  get "celestial/moon", to: "celestial#moon"

  get "up" => "rails/health#show", as: :rails_health_check
end

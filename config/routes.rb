require "sidekiq/web" # require the web UI

Rails.application.routes.draw do
  root "root#index"

  namespace :api do
    namespace :v1 do
      post :weather_measurement, to: "weather_measurements#create"
      post "weather_measurement/bulk", to: "weather_measurements#bulk_create"
    end
  end

  mount OasRails::Engine => "/docs"

  # basic auth for sidekiq dashboard
  if ENV["SIDEKIQ_USER"] && ENV["SIDEKIQ_PASSWORD"] && Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |user, password|
      user == ENV["SIDEKIQ_USER"] && password == ENV["SIDEKIQ_PASSWORD"]
    end
  end
  mount Sidekiq::Web => "/sidekiq"

  get "up" => "rails/health#show", as: :rails_health_check
end

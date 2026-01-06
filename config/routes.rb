Rails.application.routes.draw do
  root "root#index"

  namespace :api do
    namespace :v1 do
      post :weather_measurement, to: "weather_measurements#create"
      post "weather_measurement/bulk", to: "weather_measurements#bulk_create"
    end
  end

  mount OasRails::Engine => "/docs"

  get "up" => "rails/health#show", as: :rails_health_check
end

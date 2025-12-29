Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post :weather_measurement, to: "weather_measurements#create"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end

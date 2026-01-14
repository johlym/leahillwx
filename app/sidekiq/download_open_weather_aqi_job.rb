class DownloadOpenWeatherAqiJob
  include Sidekiq::Job

  def perform(*args)
    ow_aqi = OpenWeatherApiService.new.retrieve_aqi

    # {"coord":{"lon":-122.1846,"lat":47.3211},"list":[{"main":{"aqi":1},"components":{"co":273.37,"no":0.06,"no2":12.74,"o3":26.17,"so2":0.61,"pm2_5":4.85,"pm10":6.33,"nh3":1.45},"dt":1768368657}]}
    mapped = ow_aqi["list"][0]["components"].map { |k, v| [ k, v ] }
    aqi = Aqi.new(mapped.to_h)
    aqi.save
  end
end

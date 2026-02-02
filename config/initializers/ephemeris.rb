Rails.application.config.after_initialize do
  # Preload DE440s ephemeris data into memory on app boot
  # This ensures the ephemeris file is loaded once and shared across all requests
  begin
    Almanac::EphemerisLoader.instance
    Rails.logger.info "Ephemeris initialization complete"
  rescue => e
    Rails.logger.error "Failed to initialize ephemeris: #{e.message}"
    # Allow app to boot even if ephemeris fails to load
    # Individual almanac requests will fail gracefully
  end
end

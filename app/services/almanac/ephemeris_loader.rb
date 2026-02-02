module Almanac
  class EphemerisLoader
    include Singleton

    BSP_PATH = Rails.root.join("vendor", "de440s.bsp")

    attr_reader :spk

    def initialize
      load_ephemeris
    end

    def load_ephemeris
      unless File.exist?(BSP_PATH)
        raise "BSP file not found at #{BSP_PATH}. Please place de440s.bsp in vendor/"
      end

      Rails.logger.info "Loading DE440s ephemeris from #{BSP_PATH}..."
      @spk = Ephem::SPK.open(BSP_PATH.to_s)
      Rails.logger.info "DE440s ephemeris loaded successfully"
    rescue => e
      Rails.logger.error "Failed to load ephemeris: #{e.message}"
      raise
    end

    def reload!
      @spk = nil
      load_ephemeris
    end
  end
end

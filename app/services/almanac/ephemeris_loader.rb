module Almanac
  class EphemerisLoader
    BSP_PATH = Rails.root.join("vendor", "de440s.bsp")

    class << self
      # Process-aware instance cache for parallel test workers
      def instance
        current_pid = Process.pid

        # If we're in a different process (e.g., parallel test worker), create new instance
        if @instance.nil? || @pid != current_pid
          @pid = current_pid
          @instance = new
        end

        @instance
      end
    end

    attr_reader :spk

    def initialize
      load_ephemeris
    end

    def load_ephemeris
      unless File.exist?(BSP_PATH)
        raise "BSP file not found at #{BSP_PATH}. Please place de440s.bsp in vendor/"
      end

      Rails.logger.info "[PID #{Process.pid}] Loading DE440s ephemeris from #{BSP_PATH}..."
      @spk = Ephem::SPK.open(BSP_PATH.to_s)
      Rails.logger.info "[PID #{Process.pid}] DE440s ephemeris loaded successfully"
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

# frozen_string_literal: true

module ThirdPartyWeather
  class Base
    SOFTWARE_TYPE = "lhwx"
    HTTP_TIMEOUT = 10
    RESPONSE_BODY_LOG_LIMIT = 240

    def self.call(measurement_or_id, **kwargs)
      new(measurement_or_id, **kwargs).call
    end

    def initialize(measurement_or_id, lock_key: nil)
      @measurement_or_id = measurement_or_id
      @lock_key = lock_key || default_lock_key
    end

    def call
      return unless configured?

      measurement = resolve_measurement

      unless claim_send_slot!
        Rails.logger.info "[#{service_name}] skipped: min interval #{min_interval.inspect} not elapsed"
        return
      end

      Rails.logger.info(
        "[#{service_name}] uploading measurement ##{measurement.id} " \
        "(#{measurement.reading_date_time.utc.strftime('%Y-%m-%d %H:%M:%S')} UTC)"
      )

      begin
        upload(measurement)
      rescue StandardError => e
        release_send_slot!
        Rails.logger.error "[#{service_name}] raised #{e.class}: #{e.message}"
        raise
      end
    end
    alias perform call

    private

    def upload(_measurement)
      raise NotImplementedError, "#{self.class}#upload must be implemented"
    end

    def service_name
      raise NotImplementedError, "#{self.class}#service_name must be implemented"
    end

    def required_env
      raise NotImplementedError, "#{self.class}#required_env must be implemented"
    end

    def min_interval
      nil
    end

    def configured?
      missing = required_env.reject { |key| ENV[key].present? }
      return true if missing.empty?

      Rails.logger.debug "[#{service_name}] skipped: missing #{missing.join(', ')}"
      false
    end

    def resolve_measurement
      case @measurement_or_id
      when WeatherMeasurement
        @measurement_or_id
      else
        WeatherMeasurement.find(@measurement_or_id)
      end
    end

    def default_lock_key
      "third_party_upload:#{service_name}:last_sent_at"
    end

    def claim_send_slot!
      return true unless min_interval

      Sidekiq.redis do |conn|
        conn.set(@lock_key, Time.current.to_f.to_s, nx: true, ex: min_interval.to_i)
      end
    end

    def release_send_slot!
      return unless min_interval

      Sidekiq.redis { |conn| conn.del(@lock_key) }
    end

    def sanitize_response_body(body)
      self.class.sanitize_response_body(body)
    end

    def self.sanitize_response_body(body)
      text = body.to_s.strip
      return text if text.blank?

      if text.match?(/<\s*html/i)
        return "(HTML response, #{text.bytesize} bytes)"
      end

      text.length > RESPONSE_BODY_LOG_LIMIT ? "#{text[0, RESPONSE_BODY_LOG_LIMIT]}…" : text
    end

    def log_http_success(code, detail)
      Rails.logger.info "[#{service_name}] success (HTTP #{code}): #{detail}"
    end

    def log_http_failure(code, detail)
      Rails.logger.error "[#{service_name}] failed (HTTP #{code}): #{detail}"
    end
  end
end

# frozen_string_literal: true

# Thin HTTParty wrapper with consistent timeouts and status checks.
class HttpClient
  DEFAULT_TIMEOUT = 10

  class RequestError < StandardError; end

  # Transient transport failures from upstream APIs. Jobs that call external
  # services should treat these as RequestError (best-effort sync).
  NETWORK_ERRORS = [
    Timeout::Error,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::EPIPE,
    SocketError,
    OpenSSL::SSL::SSLError,
    EOFError
  ].freeze

  def self.get(url, query: nil, timeout: DEFAULT_TIMEOUT)
    options = { timeout: timeout }
    options[:query] = query unless query.nil?
    response = HTTParty.get(url, **options)
    unless response.success?
      raise RequestError, "HTTP GET #{url} failed with status #{response.code}"
    end
    response
  rescue *NETWORK_ERRORS => e
    raise RequestError, "HTTP GET #{url} failed: #{e.class}: #{e.message}"
  end

  def self.get_json(url, query: nil, timeout: DEFAULT_TIMEOUT)
    response = get(url, query: query, timeout: timeout)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise RequestError, "HTTP GET #{url} returned invalid JSON: #{e.message}"
  end
end

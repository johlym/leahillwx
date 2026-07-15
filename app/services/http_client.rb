# frozen_string_literal: true

# Thin HTTParty wrapper with consistent timeouts and status checks.
class HttpClient
  DEFAULT_TIMEOUT = 10

  class RequestError < StandardError; end

  def self.get(url, query: nil, timeout: DEFAULT_TIMEOUT)
    options = { timeout: timeout }
    options[:query] = query unless query.nil?
    response = HTTParty.get(url, **options)
    unless response.success?
      raise RequestError, "HTTP GET #{url} failed with status #{response.code}"
    end
    response
  end

  def self.get_json(url, query: nil, timeout: DEFAULT_TIMEOUT)
    response = get(url, query: query, timeout: timeout)
    JSON.parse(response.body)
  end
end

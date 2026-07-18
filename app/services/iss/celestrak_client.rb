# frozen_string_literal: true

module Iss
  # Fetches the current ISS TLE from CelesTrak.
  class CelestrakClient
    URL = "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=tle"
    TIMEOUT_SECONDS = 15

    def fetch_tle
      response = HttpClient.get(URL, timeout: TIMEOUT_SECONDS)
      Tle.parse(response.body)
    end
  end
end

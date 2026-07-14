class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_cache_headers, if: -> { Rails.env.production? }
  before_action :resolve_palette

  private

  def set_cache_headers
    response.headers["Cache-Control"] = "no-cache, private"
    response.headers["ETag"] = Rails.application.config.boot_etag
  end

  # Sets @palette, @palette_almanac, @palette_next_transition_at for the
  # layout to render on <html>. Uses today's almanac entry so the server
  # can render the correct palette immediately; the client re-syncs and
  # schedules the next boundary transition without polling.
  def resolve_palette
    now = Time.current
    @palette_almanac = AlmanacEntry.for_date(Time.zone.today)
    resolver = PaletteResolver.new(almanac: @palette_almanac, at: now)
    @palette = resolver.palette
    @palette_next_transition_at = resolver.next_transition_at
  end
end

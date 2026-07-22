require "test_helper"
require "capybara/cuprite"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, using: :chrome, screen_size: [ 1400, 1400 ], options: {
    js_errors: true,
    headless: true,
    # Page command timeout (Ferrum).
    timeout: 30,
    # Chrome startup can exceed Ferrum's 10s default under CI load
    # (`Ferrum::ProcessTimeoutError: Browser did not produce websocket url`).
    process_timeout: 30,
    browser_options: { "no-sandbox": nil }
  }
end

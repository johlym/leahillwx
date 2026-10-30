# frozen_string_literal: true

# N+1 detection. Replaces Bullet: the page footer, browser console, Rails log,
# and log/prosopite.log in development, and a test failure for each N+1.
# https://github.com/charkost/prosopite
if Rails.env.development?
  # Tests scan each example themselves, so the Rack middleware stays in development.
  require "prosopite/middleware/rack"
  Rails.configuration.middleware.use(Prosopite::Middleware::Rack)
end

Rails.application.config.after_initialize do
  if Rails.env.development?
    Prosopite.rails_logger = true
    Prosopite.prosopite_logger = true
    Prosopite.add_footer = true
    Prosopite.browser_console = true
  elsif Rails.env.test?
    Prosopite.rails_logger = true
    Prosopite.raise = true
    Prosopite.github_annotations = ENV["GITHUB_ACTIONS"].present?
  end
end

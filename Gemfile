source "https://rubygems.org"

ruby file: ".ruby-version"

gem "barnes", "~> 1.0"
gem "bootsnap", "~> 1.25", require: false
gem "cssbundling-rails", "~> 1.4"
gem "dotenv", "~> 3.2"
gem "ephem", "~> 0.5"
gem "httparty", "~> 0.24.0"
gem "jbuilder", "~> 2.14"
gem "jsbundling-rails", "~> 1.3"
gem "oas_rails", "~> 1.3"
gem "parallel", "~> 2.3"
gem "pg", "~> 1.6"
gem "propshaft", "~> 1.3"
gem "puma", ">= 8.0"
# 8.1.4 accepts redis-rb 6 in the Action Cable adapter. 8.1.3.x raises
# Gem::LoadError (can't activate redis >= 4, < 6) once redis 6 is loaded.
gem "rails", "~> 8.1.4"
gem "redis", ">= 5.4"
# Floors for 2026 advisories so Bundler cannot activate a vulnerable copy.
# crass GHSA-pq4g-8rxf-4g29; erb CVE-2026-41316;
# resolv CVE-2026-80212 and CVE-2026-80213; zlib CVE-2026-27820.
gem "crass", ">= 1.0.8"
gem "erb", ">= 6.0.7"
gem "resolv", ">= 0.7.2"
gem "zlib", ">= 3.2.3"
gem "rack-attack", "~> 6.7"
gem "sentry-rails"
gem "sentry-ruby"
gem "sentry-sidekiq"
gem "sidekiq", "~> 8.1"
gem "sidekiq-cron", "~> 2.3"
gem "stimulus-rails", "~> 1.3"
gem "turbo-rails", "~> 2.0"
gem "view_component", "~> 4.15"
gem "strong_migrations"

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "database_consistency", require: false
  # N+1 detection. PostgreSQL fingerprints work without the optional pg_query extension.
  gem "prosopite", "~> 2.5"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "annotaterb"
  gem "web-console"
  gem "ruby-lsp-rails", require: false
end

group :test do
  gem "capybara"
  gem "cuprite"
  gem "simplecov", require: false
end

gem "astronoby", "~> 0.10.0"

# Be sure to restart your server when you modify this file.
#
# Production ships Content-Security-Policy-Report-Only first so we can
# collect violations (Font Awesome kit, Fathom, Sentry, CARTO / MapLibre,
# LibreWXR, Action Cable) without breaking the dashboard. Do not flip
# report_only to false in this change.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

if Rails.env.production?
  Rails.application.configure do
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.object_src  :none
      policy.base_uri    :self
      policy.font_src    :self, :data, "https://fonts.gstatic.com", "https://ka-f.fontawesome.com",
                         "https://ka-p.fontawesome.com"
      policy.img_src     :self, :data, :blob, "https:"
      policy.script_src  :self, "https://kit.fontawesome.com", "https://ka-f.fontawesome.com",
                         "https://cdn.usefathom.com", "https://browser.sentry-cdn.com",
                         "https://*.sentry.io"
      policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com",
                         "https://ka-f.fontawesome.com", "https://kit.fontawesome.com"
      policy.connect_src :self, :https, :wss, "wss://lhwx.org",
                         "https://*.sentry.io", "https://*.ingest.sentry.io",
                         "https://cdn.usefathom.com", "https://api.librewxr.net",
                         "https://*.librewxr.net", "https://*.basemaps.cartocdn.com",
                         "https://basemaps.cartocdn.com", "https://unidata-nexrad-level3.s3.amazonaws.com",
                         "https://thredds.ucar.edu"
      policy.worker_src  :self, :blob
      policy.child_src   :self, :blob
      policy.frame_src   :none
    end

    config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
    config.content_security_policy_nonce_directives = %w[script-src]
    config.content_security_policy_report_only = true
  end
end

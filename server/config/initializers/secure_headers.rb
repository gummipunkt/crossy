# frozen_string_literal: true

require "uri"

# CSP host sources from ENV (same defaults as Threads/Bluesky integration) plus CSP_CONNECT_SRC_EXTRA.
module SecureHeadersCspOrigins
  module_function

  def connect_src
    origins = [ "'self'" ]
    origins.concat(origin_list("THREADS_GRAPH_BASE", "https://graph.threads.net"))
    origins.concat(origin_list("THREADS_OAUTH_BASE", "https://www.threads.net"))
    origins.concat(origin_list("BLUESKY_BASE", "https://bsky.social"))
    origins.concat(extra_origins)
    origins.compact.uniq
  end

  def threads_frame_origins
    origin_list("THREADS_OAUTH_BASE", "https://www.threads.net").uniq
  end

  def extra_origins
    ENV.fetch("CSP_CONNECT_SRC_EXTRA", "").split(",").map(&:strip).reject(&:blank?)
  end

  def origin_list(env_key, default)
    raw = ENV.fetch(env_key, default).to_s.strip
    return [] if raw.blank?

    uri = URI.parse(raw.match?(/\Ahttps?:\/\//i) ? raw : "https://#{raw}")
    return [] if uri.host.blank?

    scheme = (uri.scheme.presence || "https").downcase
    return [] unless %w[http https].include?(scheme)

    host = uri.host
    default_port = scheme == "https" ? 443 : 80
    port = uri.port
    origin =
      if port && port != default_port
        "#{scheme}://#{host}:#{port}"
      else
        "#{scheme}://#{host}"
      end
    [ origin ]
  rescue URI::InvalidURIError
    []
  end
end

SecureHeaders::Configuration.default do |config|
  config.hsts = "max-age=31536000; includeSubDomains"
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"

  thread_frames = SecureHeadersCspOrigins.threads_frame_origins
  config.csp = {
    default_src: [ "'self'" ],
    script_src: [ "'self'", "'unsafe-inline'" ],
    style_src: [ "'self'", "'unsafe-inline'", "https://fonts.googleapis.com" ],
    font_src: [ "'self'", "https://fonts.gstatic.com" ],
    # Remote images (timelines, avatars); Mastodon/Bluesky/CDN hosts vary
    img_src: [ "'self'", "data:", "https:", "http:" ],
    connect_src: SecureHeadersCspOrigins.connect_src,
    frame_ancestors: [ "'self'" ],
    frame_src: [ "'self'", *(thread_frames.presence || [ "https://www.threads.net" ]) ],
    child_src: [ "'self'", *(thread_frames.presence || [ "https://www.threads.net" ]) ]
  }
end

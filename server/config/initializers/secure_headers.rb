SecureHeaders::Configuration.default do |config|
  config.hsts = "max-age=31536000; includeSubDomains"
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"
  config.csp = {
    default_src: ["'self'"],
    script_src: ["'self'", "'unsafe-inline'"],
    style_src: ["'self'", "'unsafe-inline'"],
    # Remote Images from external providers
    img_src: ["'self'", "data:", "https:", "http:"],
    connect_src: ["'self'", "https://graph.threads.net", "https://www.threads.net"],
    frame_ancestors: ["'self'"],
    frame_src: ["'self'", "https://www.threads.net"],
    child_src: ["'self'", "https://www.threads.net"]
  }
end



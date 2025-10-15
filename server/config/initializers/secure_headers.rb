SecureHeaders::Configuration.default do |config|
  config.hsts = "max-age=31536000; includeSubDomains"
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"
  config.csp = {
    default_src: ["'self'"],
    script_src: ["'self'", "'unsafe-inline'"],
    style_src: ["'self'", "'unsafe-inline'"],
    # Remote Bilder von externen Providern erlauben
    img_src: ["'self'", "data:", "https:", "http:"],
    connect_src: ["'self'"]
  }
end



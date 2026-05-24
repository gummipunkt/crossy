# CORS for the native mobile API. Browser clients keep using session
# cookies on the same origin, so this only opens up /api/v1/* and never
# sets credentials: true (we authenticate the mobile app via Bearer token).
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/api/v1/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ],
      credentials: false,
      max_age: 600
  end
end

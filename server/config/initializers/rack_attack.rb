class Rack::Attack
  throttle("req/ip", limit: 100, period: 1.minute) { |req| req.ip }

  throttle("logins/ip", limit: 20, period: 5.minutes) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("api_logins/ip", limit: 20, period: 5.minutes) do |req|
    req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
  end

  throttle("sign_up/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end
end

# rack-attack's Railtie already inserts the middleware; adding it again here
# counted every request twice and halved all limits.

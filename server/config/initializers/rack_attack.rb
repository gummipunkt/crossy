class Rack::Attack
  throttle("req/ip", limit: 100, period: 1.minute) { |req| req.ip }

  throttle("logins/ip", limit: 20, period: 5.minutes) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("sign_up/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end
end

Rails.application.config.middleware.use Rack::Attack

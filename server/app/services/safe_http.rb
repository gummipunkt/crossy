require "faraday"

# Faraday connections to hosts that come from users (Mastodon instances,
# custom Bluesky PDS). The host is resolved and checked once and the
# connection is pinned to that address, so a DNS answer that changes between
# the check and the request (DNS rebinding) cannot point it at an internal
# service. TLS still verifies the certificate against the hostname.
#
# The block configures middleware only; the adapter is set here. Behind an
# outbound HTTP proxy the proxy resolves the host, so pinning does not apply.
module SafeHttp
  DEFAULT_TIMEOUTS = { timeout: 15, open_timeout: 5 }.freeze

  module_function

  def connection(base_url, request: DEFAULT_TIMEOUTS)
    _uri, ip = SsrfSafeUrlValidator.resolve!(base_url)
    Faraday.new(url: base_url, request: request) do |f|
      yield f if block_given?
      f.adapter(:net_http) { |http| http.ipaddr = ip }
    end
  end
end

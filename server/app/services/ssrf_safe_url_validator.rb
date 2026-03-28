# frozen_string_literal: true

require "ipaddr"
require "resolv"
require "timeout"
require "uri"

# Rejects user-controlled base URLs that would target loopback, RFC1918, link-local,
# or cloud metadata endpoints (mitigates SSRF when the app fetches those URLs).
class SsrfSafeUrlValidator
  class Error < StandardError; end

  DISALLOWED_HOSTNAMES = %w[localhost].freeze
  DNS_TIMEOUT_SEC = 5

  def self.validate!(url_string, allow_http: !Rails.env.production?)
    uri = URI.parse(url_string.to_s.strip)
    raise Error, "URL scheme not allowed" unless allowed_scheme?(uri.scheme, allow_http: allow_http)
    raise Error, "host required" if uri.host.blank?
    raise Error, "userinfo not allowed in URL" if uri.user || uri.password

    host = uri.host.downcase
    raise Error, "host not allowed" if DISALLOWED_HOSTNAMES.include?(host)

    if (literal_ip = ip_literal(host))
      raise_disallowed_ip!(literal_ip)
    else
      resolve_and_check_ips!(host)
    end

    uri
  end

  class << self
    private

    def allowed_scheme?(scheme, allow_http:)
      return false if scheme.blank?

      case scheme.downcase
      when "https" then true
      when "http" then allow_http
      else false
      end
    end

    def ip_literal(host)
      IPAddr.new(host)
    rescue IPAddr::InvalidAddressError
      nil
    end

    def raise_disallowed_ip!(ip)
      raise Error, "IP address not allowed" if disallowed_ip?(ip)
    end

    def disallowed_ip?(ip)
      ip.loopback? || ip.private? || ip.link_local?
    end

    def resolve_and_check_ips!(host)
      addresses = Timeout.timeout(DNS_TIMEOUT_SEC) { Resolv.getaddresses(host) }
      raise Error, "host could not be resolved" if addresses.empty?

      addresses.each do |addr|
        ip = IPAddr.new(addr)
        raise_disallowed_ip!(ip)
      end
    rescue Timeout::Error
      raise Error, "DNS resolution timed out"
    rescue IPAddr::InvalidAddressError
      raise Error, "invalid resolved address"
    end
  end
end

require "test_helper"

class SsrfSafeUrlValidatorTest < ActiveSupport::TestCase
  BLOCKED = %w[
    https://127.0.0.1 https://10.0.0.5 https://192.168.1.1 https://169.254.169.254
    https://0.0.0.0 https://100.64.0.1 https://224.0.0.1 https://240.0.0.1
    https://[::1] https://[::] https://[fd00::1] https://[fe80::1]
    https://[::ffff:127.0.0.1] https://[::ffff:169.254.169.254] https://[::127.0.0.1]
    https://localhost https://localhost.
  ].freeze

  BLOCKED.each do |url|
    test "blocks #{url}" do
      assert_raises(SsrfSafeUrlValidator::Error) { SsrfSafeUrlValidator.validate!(url, allow_http: false) }
    end
  end

  test "allows public IP literals" do
    assert SsrfSafeUrlValidator.validate!("https://8.8.8.8", allow_http: false)
    assert SsrfSafeUrlValidator.validate!("https://[2606:4700:4700::1111]", allow_http: false)
  end

  test "rejects plain http unless allowed" do
    assert_raises(SsrfSafeUrlValidator::Error) { SsrfSafeUrlValidator.validate!("http://8.8.8.8", allow_http: false) }
  end

  test "rejects userinfo" do
    assert_raises(SsrfSafeUrlValidator::Error) { SsrfSafeUrlValidator.validate!("https://user:pw@8.8.8.8", allow_http: false) }
  end
end

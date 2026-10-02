require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "safe_external_url keeps http(s) links only" do
    assert_equal "https://example.com/a", safe_external_url("https://example.com/a")
    assert_equal "http://example.com", safe_external_url(" http://example.com ")
    assert_nil safe_external_url("javascript:alert(1)")
    assert_nil safe_external_url("JaVaScRiPt:alert(1)")
    assert_nil safe_external_url("data:text/html,hi")
    assert_nil safe_external_url("//example.com")
    assert_nil safe_external_url(nil)
  end
end

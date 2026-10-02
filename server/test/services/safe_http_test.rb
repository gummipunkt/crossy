require "test_helper"
require "socket"

class SafeHttpTest < ActiveSupport::TestCase
  test "connects to the vetted address, not to a fresh DNS answer" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    received_host = nil
    thread = Thread.new do
      client = server.accept
      while (line = client.gets) && line != "\r\n"
        received_host = line.split(": ", 2).last.strip if line.downcase.start_with?("host:")
      end
      client.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
      client.close
    end

    # "pinned.invalid" cannot resolve; the request can only arrive here because
    # the connection uses the address returned by the validator.
    url = "http://pinned.invalid:#{port}"
    resolver = ->(_url, **) { [ URI.parse(url), "127.0.0.1" ] }
    with_stubbed_singleton(SsrfSafeUrlValidator, :resolve!, resolver) do
      assert_equal "ok", SafeHttp.connection(url).get("/").body
    end
    thread.join(5)
    assert_equal "pinned.invalid:#{port}", received_host
  ensure
    server&.close
  end

  test "refuses hosts the validator rejects" do
    assert_raises(SsrfSafeUrlValidator::Error) { SafeHttp.connection("https://127.0.0.1") }
  end

  test "resolve! returns the literal address" do
    _uri, ip = SsrfSafeUrlValidator.resolve!("https://8.8.8.8", allow_http: false)
    assert_equal "8.8.8.8", ip
  end

  private

  def with_stubbed_singleton(object, name, implementation)
    original = object.method(name)
    object.define_singleton_method(name, implementation)
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end

require "test_helper"

class Threads::TokenRefresherTest < ActiveSupport::TestCase
  setup do
    @account = create_user.provider_accounts.create!(provider: "threads", handle: "42", access_token: "old", threads_token_expires_at: 2.days.from_now)
  end

  test "stores the new token and expiry" do
    refresher = refresher_returning(200, access_token: "new", expires_in: 5_184_000)

    assert_equal "new", refresher.refresh!
    @account.reload
    assert_equal "new", @account.access_token
    assert_in_delta 60.days.from_now, @account.threads_token_expires_at, 5.seconds
    assert_equal "active", @account.status
  end

  test "marks the account for reconnecting when Threads rejects the token" do
    refresher = refresher_returning(400, error: { code: 190 })

    assert_nil refresher.refresh!
    assert_equal "reauth_required", @account.reload.status
    assert_equal "old", @account.access_token
  end

  test "does not flag the account on a server error" do
    refresher = refresher_returning(503, {})

    assert_raises(RuntimeError) { refresher.refresh! }
    assert_equal "active", @account.reload.status
  end

  private

  def refresher_returning(status, body)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/refresh_access_token") { [ status, {}, body.to_json ] }
    refresher = Threads::TokenRefresher.new(@account)
    refresher.define_singleton_method(:connection) { Faraday.new { |f| f.adapter :test, stubs } }
    refresher
  end
end

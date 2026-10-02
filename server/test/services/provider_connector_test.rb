require "test_helper"

class ProviderConnectorTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @connector = ProviderConnector.new(@user)
  end

  test "rejects a Mastodon token without a posting scope and saves nothing" do
    stub_mastodon(scopes: "read")

    error = assert_raises(ProviderConnector::Error) { connect_mastodon }
    assert_match "write:statuses", error.message
    assert_equal 0, @user.provider_accounts.count
  end

  test "accepts the umbrella write scope" do
    stub_mastodon(scopes: "read write follow")

    account = connect_mastodon
    assert account.persisted?
    assert_equal "read write follow", account.scopes
  end

  test "reconnecting a Mastodon account updates its token instead of failing" do
    stub_mastodon(scopes: "write:statuses")
    first = connect_mastodon(token: "old")
    second = connect_mastodon(token: "new")

    assert_equal first.id, second.id
    assert_equal "new", second.reload.access_token
  end

  test "a failed Bluesky login leaves no account behind" do
    with_stubbed_method(Posting::BlueskyClient, :login!, ->(_password) { raise "Bluesky login error: 401" }) do
      assert_raises(RuntimeError) { @connector.bluesky!(handle: "me.bsky.social", app_password: "wrong") }
    end
    assert_equal 0, @user.provider_accounts.count
  end

  test "a successful Bluesky login saves the account" do
    with_stubbed_method(Posting::BlueskyClient, :login!, ->(_password) { @provider_account.update!(refresh_token: "jwt") }) do
      @connector.bluesky!(handle: "me.bsky.social", app_password: "right")
    end
    assert_equal "jwt", @user.provider_accounts.find_by!(provider: "bluesky").refresh_token
  end

  test "rejects a Nostr key that is not hex" do
    error = assert_raises(ProviderConnector::Error) { @connector.nostr!(handle: "me", public_key: "npub1abc") }
    assert_match "64 hex", error.message
  end

  private

  def connect_mastodon(token: "tok")
    @connector.mastodon!(handle: "me", instance: "https://8.8.8.8", access_token: token)
  end

  def stub_mastodon(scopes:)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/api/v1/accounts/verify_credentials") { [ 200, {}, "{}" ] }
    stubs.get("/oauth/token/info") { [ 200, {}, { scopes: scopes.split }.to_json ] }
    @connector.define_singleton_method(:connection) do |_instance|
      Faraday.new { |f| f.adapter :test, stubs }
    end
  end
end

require "test_helper"

class FeedInteractionTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @first = @user.provider_accounts.create!(provider: "mastodon", handle: "a", instance: "https://one.example", access_token: "tok-a")
    @second = @user.provider_accounts.create!(provider: "mastodon", handle: "b", instance: "https://two.example", access_token: "tok-b")
  end

  test "acts through the account the item came from" do
    calls = perform(provider_account_id: @second.id)
    assert_equal [ [ "https://two.example", "/api/v1/statuses/42/favourite", "Bearer tok-b" ] ], calls
  end

  test "falls back to the first account for clients that send no account id" do
    calls = perform(provider_account_id: nil)
    assert_equal "https://one.example", calls.first.first
  end

  test "cannot act through another user's account" do
    other = create_user.provider_accounts.create!(provider: "mastodon", handle: "x", instance: "https://x.example", access_token: "t")
    assert_raises(ActiveRecord::RecordNotFound) { perform(provider_account_id: other.id) }
  end

  test "escapes the item id in the request path" do
    calls = perform(provider_account_id: @first.id, item_id: "../../admin")
    assert_equal "/api/v1/statuses/..%2F..%2Fadmin/favourite", calls.first[1]
  end

  private

  def perform(provider_account_id:, item_id: "42")
    calls = []
    interaction = FeedInteraction.new(@user)
    interaction.define_singleton_method(:connection) do |base_url|
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.post(%r{/api/v1/statuses/}) do |env|
        calls << [ base_url, env.url.path, env.request_headers["Authorization"] ]
        [ 200, {}, "{}" ]
      end
      Faraday.new(url: base_url) { |f| f.adapter :test, stubs }
    end
    assert interaction.perform!(provider: "mastodon", item_id: item_id, action: "like", provider_account_id: provider_account_id)
    calls
  end
end

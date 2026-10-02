require "test_helper"

class FeedAggregatorTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @healthy = @user.provider_accounts.create!(provider: "mastodon", handle: "a", instance: "https://up.example", access_token: "t")
    @broken = @user.provider_accounts.create!(provider: "mastodon", handle: "b", instance: "https://down.example", access_token: "t")
  end

  test "a failing account does not empty the timeline and items carry their account" do
    items = aggregate(
      "https://up.example" => [ status("1") ],
      "https://down.example" => Faraday::ConnectionFailed.new("refused")
    )

    assert_equal [ "1" ], items.map(&:id)
    assert_equal @healthy.id, items.first.provider_account_id
  end

  test "a post seen by two accounts is shown once" do
    items = aggregate("https://up.example" => [ status("7") ], "https://down.example" => [ status("7") ])
    assert_equal [ "7" ], items.map(&:id)
  end

  private

  def status(id)
    { id: id, created_at: Time.current.iso8601, content: "<p>hi</p>", account: { acct: "someone" } }
  end

  def aggregate(responses)
    aggregator = FeedAggregator.new
    aggregator.define_singleton_method(:connection) do |base_url|
      response = responses.fetch(base_url)
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get("/api/v1/timelines/home") do
        raise response if response.is_a?(Exception)
        [ 200, {}, response.to_json ]
      end
      Faraday.new(url: base_url) { |f| f.adapter :test, stubs }
    end
    aggregator.aggregate(limit: 10, user: @user)
  end
end

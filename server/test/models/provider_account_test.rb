require "test_helper"

class ProviderAccountTest < ActiveSupport::TestCase
  test "can be removed while it has Threads follows" do
    account = create_user.provider_accounts.create!(provider: "threads", handle: "42", access_token: "t")
    account.threads_follows.create!(username: "someone")

    assert_difference -> { ThreadsFollow.count }, -1 do
      account.destroy!
    end
  end
end

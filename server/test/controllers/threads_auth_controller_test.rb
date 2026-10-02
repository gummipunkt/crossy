require "test_helper"

class ThreadsAuthControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in create_user
  end

  test "rejects a callback without any state" do
    get "/auth/threads/callback", params: { code: "attacker-code" }

    assert_redirected_to new_post_path
    assert_equal "Invalid OAuth State", flash[:alert]
  end

  test "rejects a callback whose state was never issued to this session" do
    get "/auth/threads/callback", params: { code: "attacker-code", state: "guessed" }

    assert_redirected_to new_post_path
    assert_equal "Invalid OAuth State", flash[:alert]
  end

  test "rejects a state that does not match the issued one" do
    with_env("THREADS_APP_ID" => "app") { get "/auth/threads" }
    assert_response :redirect

    get "/auth/threads/callback", params: { code: "attacker-code", state: "wrong" }
    assert_equal "Invalid OAuth State", flash[:alert]
  end
end

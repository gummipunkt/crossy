require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    admin = create_user
    admin.update!(admin: true)
    sign_in admin
    @user = create_user
  end

  test "changing only the e-mail keeps the password" do
    patch admin_user_path(@user), params: { user: { email: "new@example.com", password: "", password_confirmation: "" } }

    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "new@example.com", @user.email
    assert @user.valid_password?("password123")
  end
end

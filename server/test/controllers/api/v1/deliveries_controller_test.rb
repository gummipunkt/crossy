require "test_helper"

class Api::V1::DeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    account = @user.provider_accounts.create!(provider: "mastodon", handle: "me", instance: "https://social.example", access_token: "t")
    @post = @user.posts.create!(content_text: "hi")
    @delivery = Delivery.create!(post: @post, provider_account: account, status: "failed", error_message: "x", dedup_key: "k")
    @headers = { "Authorization" => "Bearer #{ApiToken.issue!(user: @user).raw_token}" }
  end

  test "retries a failed delivery" do
    assert_enqueued_with(job: PostDeliveryJob, args: [ @delivery.id ]) do
      post retry_api_v1_post_delivery_path(@post, @delivery), headers: @headers
    end
    assert_response :accepted
    assert_equal "queued", response.parsed_body.dig("delivery", "status")
  end

  test "refuses to retry a delivery that did not fail" do
    @delivery.update!(status: "succeeded")
    post retry_api_v1_post_delivery_path(@post, @delivery), headers: @headers
    assert_response :unprocessable_entity
  end

  test "creates a scheduled post" do
    post api_v1_posts_path, headers: @headers,
         params: { content_text: "later", scheduled_at: 3.hours.from_now.iso8601, provider_account_ids: [ @delivery.provider_account_id ] }

    assert_response :accepted
    assert response.parsed_body["scheduled_at"].present?
    assert_equal "scheduled", response.parsed_body["deliveries"].first["status"]
  end
end

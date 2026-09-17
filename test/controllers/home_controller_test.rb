require "test_helper"

class Accounts::HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
  end

  test "dashboard renders operational conversation summary" do
    get account_home_url(@account)

    assert_response :success
    assert_select "h1", text: /Good to see you/
    assert_select "[aria-label='Conversation summary']"
    assert_select "a[href='#{account_inbox_path(@account, filter: 'mine')}']", text: /Assigned to me/
    assert_select "a[href='#{account_inbox_path(@account, filter: 'unowned')}']", text: /Unassigned/
    assert_select "h2", text: "Recent conversations"
  end

  test "dashboard remains account scoped" do
    get account_home_url(@account)

    assert_response :success
    assert_select "body", text: /Wilma Customer/
    assert_select "body", text: /Greg Customer/, count: 0
  end
end

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
  end

  test "index lists user's active memberships with cursor pagination" do
    get accounts_url
    assert_response :success
    assert_select "a[href*='a/']", minimum: 2
  end

  test "create builds Account + Membership + Agent + General Team atomically" do
    post accounts_url, params: { account: { name: "Integration Garden", operation_key: "int-op-key-1" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match "Integration Garden", response.body

    account = Account.find_by(name: "Integration Garden")
    assert account.persisted?
    assert_equal 1, account.memberships.active.count
    assert_equal 1, account.agents.count
    assert_equal 1, account.teams.count
    assert_equal "General", account.teams.first.name
  end

  test "duplicate operation_key does not create second Account" do
    post accounts_url, params: { account: { name: "First", operation_key: "dedupe-key" } }
    first_id = Account.find_by(creation_operation_key: "dedupe-key").id

    post accounts_url, params: { account: { name: "Second", operation_key: "dedupe-key" } }
    second_id = Account.find_by(creation_operation_key: "dedupe-key").id

    assert_equal first_id, second_id
    assert_equal 1, Account.where(creation_operation_key: "dedupe-key").count
  end

  test "invalid name shows validation errors" do
    post accounts_url, params: { account: { name: "", operation_key: "invalid-op" } }
    assert_response :unprocessable_content
    assert_match /can(?:&#39;|')t be blank/, response.body
  end
end

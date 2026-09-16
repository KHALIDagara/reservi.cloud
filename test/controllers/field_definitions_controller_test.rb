require "test_helper"

class Accounts::FieldDefinitionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
  end

  test "index renders" do
    get account_field_definitions_url(@account)
    assert_response :success
  end

  test "new renders form" do
    get new_account_field_definition_url(@account)
    assert_response :success
    assert_select "form"
  end

  test "create with valid params redirects" do
    post account_field_definitions_create_url(@account), params: {
      field_definition: { key: "city", label: "City", scope: "customer", field_type: "text" }
    }
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "create with reserved key shows alert" do
    post account_field_definitions_create_url(@account), params: {
      field_definition: { key: "name", scope: "customer", field_type: "text" }
    }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match /alert/, response.body, response.body
  end

  test "non-admin cannot access index" do
    sign_out
    sign_in_as(users(:bob))
    get account_field_definitions_url(@account)
    assert_response :redirect
    follow_redirect!
    assert_match /accounts/, response.body
  end

  test "non-admin cannot access new" do
    sign_out
    sign_in_as(users(:bob))
    get new_account_field_definition_url(@account)
    assert_response :redirect
    follow_redirect!
    assert_match /accounts/, response.body
  end

  test "non-admin cannot create" do
    sign_out
    sign_in_as(users(:bob))
    post account_field_definitions_create_url(@account), params: {
      field_definition: { key: "test", scope: "customer", field_type: "text" }
    }
    assert_response :redirect
    follow_redirect!
    assert_match /accounts/, response.body
  end

  test "archive field" do
    defn = @account.field_definitions.create!(scope: "customer", key: "test_field", field_type: "text", position: 1)
    post archive_account_field_definition_url(@account, defn)
    assert_response :redirect
    assert defn.reload.archived?
  end

  test "index includes only own account field definitions" do
    # Create one field definition for alpha
    @account.field_definitions.create!(scope: "customer", key: "alpha_only", field_type: "text", position: 1)
    # Create one for beta
    accounts(:beta).field_definitions.create!(scope: "customer", key: "beta_only", field_type: "text", position: 1)

    get account_field_definitions_url(@account)
    assert_response :success
    # alpha_only should appear in the list
    assert_match /alpha_only/, response.body
    # beta_only should not appear
    assert_no_match /beta_only/, response.body
  end

  test "user without beta membership cannot access beta field definitions" do
    # Bob is only in alpha, so beta access should fail
    sign_out
    sign_in_as(users(:bob))
    get account_field_definitions_url(accounts(:beta))
    assert_response :redirect
    follow_redirect!
    assert_match /accounts/, response.body
  end
end

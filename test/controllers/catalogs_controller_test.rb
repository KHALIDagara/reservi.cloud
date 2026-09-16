require "test_helper"

class Accounts::CatalogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @admin = users(:alice)
    @operator = users(:bob)

    # Create some catalogs for the account
    @account.catalogs.create!(title: "Services")
    @account.catalogs.create!(title: "Cars")
  end

  test "index renders for authenticated user" do
    sign_in_as(@admin)
    get catalogs_url(account_id: @account.id)
    assert_response :success
    assert_select "h1"
  end

  test "index requires authentication" do
    get catalogs_url(account_id: @account.id)
    assert_redirected_to new_session_path
  end

  test "new renders for admin" do
    sign_in_as(@admin)
    get new_catalog_url(account_id: @account.id)
    assert_response :success
  end

  test "new redirects non-admin" do
    sign_in_as(@operator)
    get new_catalog_url(account_id: @account.id)
    assert_redirected_to accounts_path
  end

  test "admin can create catalog" do
    sign_in_as(@admin)
    assert_difference -> { @account.catalogs.count } => 1 do
      post catalogs_url(account_id: @account.id), params: { catalog: { title: "New Catalog" } }
    end
    assert_redirected_to catalogs_url(account_id: @account.id)
    assert @account.catalogs.exists?(title: "New Catalog")
  end

  test "non-admin cannot create catalog" do
    sign_in_as(@operator)
    assert_no_difference -> { @account.catalogs.count } do
      post catalogs_url(account_id: @account.id), params: { catalog: { title: "New Catalog" } }
    end
    assert_redirected_to accounts_path
  end
end

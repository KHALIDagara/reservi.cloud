require "test_helper"

class Accounts::ItemSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @admin = users(:alice)
    @conversation = conversations(:alpha_active)
    @catalog = @account.catalogs.create!(title: "Services")
    @item = @catalog.items.create!(title: "Garden Maintenance", price: 150, currency: "USD", unit: "visit",
      account: @account)
  end

  test "create adds selection" do
    sign_in_as(@admin)

    assert_difference -> { @conversation.item_selections.count } => 1 do
      post item_selections_url(account_id: @account.id), params: {
        item_selection: { item_id: @item.id, role_key: "requested_service" },
        conversation_id: @conversation.id
      }
    end

    assert_redirected_to account_conversation_url(@account, @conversation)
    selection = @conversation.item_selections.last
    assert_equal @item, selection.item
    assert_equal "requested_service", selection.role_key
  end

  test "duplicate selection replaces (single-select)" do
    sign_in_as(@admin)

    # First selection
    post item_selections_url(account_id: @account.id), params: {
      item_selection: { item_id: @item.id, role_key: "requested_service" },
      conversation_id: @conversation.id
    }

    second_item = @catalog.items.create!(title: "Pool Cleaning", price: 200, account: @account)

    # Second selection for same role_key replaces the first
    assert_difference -> { @conversation.item_selections.count } => 0 do
      post item_selections_url(account_id: @account.id), params: {
        item_selection: { item_id: second_item.id, role_key: "requested_service" },
        conversation_id: @conversation.id
      }
    end

    selections = @conversation.item_selections.for_role("requested_service")
    assert_equal 1, selections.count
    assert_equal second_item.id, selections.first.item_id
  end

  test "destroy clears selection" do
    sign_in_as(@admin)

    # Create a selection first
    selection = @conversation.item_selections.create!(
      account: @account,
      catalog: @catalog,
      item: @item,
      role_key: "requested_service",
      snapshot: { "title" => @item.title }
    )

    assert_difference -> { @conversation.item_selections.count } => -1 do
      delete item_selection_url(account_id: @account.id, id: selection.id),
        params: { conversation_id: @conversation.id }
    end

    assert_redirected_to account_conversation_url(@account, @conversation)
  end
end

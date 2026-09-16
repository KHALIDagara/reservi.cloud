require "test_helper"

class ItemSelections::SelectTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @admin = memberships(:alpha_alice)
    @conversation = conversations(:alpha_active)
    @catalog = @account.catalogs.create!(title: "Services")
    @item = @catalog.items.create!(title: "Garden Maintenance", price: 150, currency: "USD", unit: "visit",
      account: @account)
  end

  test "selects an item and creates a selection with snapshot" do
    selection = ItemSelections::Select.call(
      conversation: @conversation,
      item: @item,
      role_key: "requested_service",
      actor_membership: @admin
    )

    assert selection.persisted?
    assert_equal @conversation, selection.conversation
    assert_equal @item, selection.item
    assert_equal "requested_service", selection.role_key
    assert_equal "Garden Maintenance", selection.snapshot["title"]
    assert_equal "150.0", selection.snapshot["price"]
    assert_equal "USD", selection.snapshot["currency"]
    assert_equal "visit", selection.snapshot["unit"]
  end

  test "archived item is rejected" do
    @item.update!(archived: true)

    assert_raises(Reservi::Errors::OperationError, match: /archived/) do
      ItemSelections::Select.call(
        conversation: @conversation,
        item: @item,
        role_key: "requested_service",
        actor_membership: @admin
      )
    end
  end

  test "foreign-account item is rejected" do
    other_account = accounts(:beta)
    other_catalog = other_account.catalogs.create!(title: "Services")
    other_item = other_catalog.items.create!(title: "Pool Cleaning", price: 200, account: other_account)

    assert_raises(Reservi::Errors::OperationError, match: /different account/) do
      ItemSelections::Select.call(
        conversation: @conversation,
        item: other_item,
        role_key: "requested_service",
        actor_membership: @admin
      )
    end
  end

  test "snapshot captures title and price at selection time" do
    # Change the item after selection
    selection = ItemSelections::Select.call(
      conversation: @conversation,
      item: @item,
      role_key: "requested_service",
      actor_membership: @admin
    )

    @item.update!(title: "Premium Garden Maintenance", price: 250)

    selection.reload
    # Snapshot should still have the original values
    assert_equal "Garden Maintenance", selection.snapshot["title"]
    assert_equal "150.0", selection.snapshot["price"]
  end
end

require "test_helper"

class ItemSelections::ClearTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @membership = memberships(:alpha_alice)
    @catalog = @account.catalogs.create!(title: "Services")
    @first_item = @catalog.items.create!(account: @account, title: "Garden care")
    @second_item = @catalog.items.create!(account: @account, title: "Pool care")
  end

  test "a stale clear cannot delete a replacement selection" do
    stale = create_selection(@first_item)
    stale.destroy!
    replacement = create_selection(@second_item)

    error = assert_raises(Reservi::Errors::OperationError) do
      ItemSelections::Clear.call(
        conversation: @conversation,
        role_key: "requested_service",
        expected_selection_id: stale.id,
        actor_membership: @membership
      )
    end

    assert_match(/Selection changed/, error.message)
    assert_equal replacement.id, @conversation.item_selections.for_role("requested_service").pick(:id)
  end

  private

  def create_selection(item)
    @conversation.item_selections.create!(
      account: @account,
      catalog: @catalog,
      item:,
      role_key: "requested_service",
      snapshot: { "title" => item.title }
    )
  end
end

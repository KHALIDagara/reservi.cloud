require "test_helper"

class ConversationRevisionTest < ActiveSupport::TestCase
  setup do
    @conversation = conversations(:alpha_active)
    @conversation.update_column(:revision, 0)
  end

  test "revision defaults to 0" do
    assert_equal 0, Conversation.new.revision
  end

  test "increments revision on meaningful update" do
    original = @conversation.revision
    @conversation.update!(attention: false)
    assert_equal original + 1, @conversation.reload.revision
  end

  test "increments revision on owner change" do
    original = @conversation.revision
    @conversation.update!(owner_id: agents(:alpha_bob_human).id)
    assert_equal original + 1, @conversation.reload.revision
  end

  test "increments revision on process_status change" do
    original = @conversation.revision
    @conversation.update!(process_status: "completed")
    assert_equal original + 1, @conversation.reload.revision
  end

  test "increments revision on custom_values change" do
    original = @conversation.revision
    @conversation.update!(custom_values: { "city" => "Marrakech" })
    assert_equal original + 1, @conversation.reload.revision
  end

  test "skips revision increment when skip_revision_increment is set" do
    original = @conversation.revision
    @conversation.skip_revision_increment = true
    @conversation.update!(attention: false, last_activity_at: Time.current)
    assert_equal original, @conversation.reload.revision
  end

  test "skip_revision_increment is single-use (cleared after callback runs)" do
    original = @conversation.revision
    @conversation.skip_revision_increment = true
    @conversation.save!
    # The save still ran the callback; skip flag was consumed
    assert_nil @conversation.skip_revision_increment

    # Next save without setting skip flag should increment
    @conversation.attention = false
    @conversation.save!
    assert_equal original + 1, @conversation.reload.revision
  end

  test "revision never decreases" do
    @conversation.update_column(:revision, 5)
    @conversation.update!(attention: false)
    assert_equal 6, @conversation.reload.revision
  end
end
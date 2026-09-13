require "test_helper"

class CustomerFields::UpdateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @admin = memberships(:alpha_alice)
    @customer = customers(:alpha_wilma)
    # Create customer-scoped field definitions
    @account.field_definitions.create!(scope: "customer", key: "city", field_type: "text", position: 1)
    @account.field_definitions.create!(scope: "customer", key: "member_since", field_type: "number", position: 2)
  end

  test "updates canonical name column" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { name: "Wilma Updated" }
    )
    @customer.reload
    assert_equal "Wilma Updated", @customer.name
    # custom_values should not contain name
    assert_nil @customer.custom_values["name"]
  end

  test "updates canonical phone column" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { phone: "+212600000000" }
    )
    @customer.reload
    assert_equal "+212600000000", @customer.phone
    assert_nil @customer.custom_values["phone"]
  end

  test "updates canonical email_address column" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { email_address: "updated@example.com" }
    )
    @customer.reload
    assert_equal "updated@example.com", @customer.email_address
  end

  test "updates custom values through definitions" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { city: "Marrakech" }
    )
    @customer.reload
    assert_equal "Marrakech", @customer.custom_values["city"]
  end

  test "increments profile_revision on update" do
    assert_equal 1, @customer.profile_revision
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { city: "Essaouira" }
    )
    @customer.reload
    assert_equal 2, @customer.profile_revision
  end

  test "invalid custom values raise error" do
    e = assert_raises(Reservi::Errors::OperationError) do
      CustomerFields::Update.call(
        customer: @customer,
        actor_membership: @admin,
        attributes: { city: 123 }
      )
    end
    assert_match /must be a string/i, e.message
  end

  test "zero persists as custom value" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { member_since: 0 }
    )
    @customer.reload
    assert_equal 0, @customer.custom_values["member_since"]
  end

  test "false persists as custom value" do
    @account.field_definitions.create!(scope: "customer", key: "vip", field_type: "boolean", position: 3)
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { vip: false }
    )
    @customer.reload
    assert_equal false, @customer.custom_values["vip"]
  end

  test "does not affect other customers" do
    other_customer = customers(:alpha_fred)
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { city: "Marrakech" }
    )
    @customer.reload
    other_customer.reload
    assert_equal "Marrakech", @customer.custom_values["city"]
    assert_nil other_customer.custom_values["city"]
  end

  test "undefined custom key is stored without validation" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { undefined_field: "value" }
    )
    @customer.reload
    assert_equal "value", @customer.custom_values["undefined_field"]
  end

  test "combined canonical and custom update works" do
    CustomerFields::Update.call(
      customer: @customer,
      actor_membership: @admin,
      attributes: { name: "New Name", city: "Rabat" }
    )
    @customer.reload
    assert_equal "New Name", @customer.name
    assert_equal "Rabat", @customer.custom_values["city"]
    assert_equal 2, @customer.profile_revision
  end
end
require "test_helper"

class Accounts::CreateTest < ActiveSupport::TestCase
  setup do
    @user = users(:dora)
  end

  test "bootstraps Account, admin Membership, human Agent and General Team atomically" do
    account = Accounts::Create.call(user: @user, name: "Marrakech Garden", operation_key: "op-key-1")

    assert account.persisted?
    assert_equal "Marrakech Garden", account.name
    assert_equal "en", account.locale
    assert_equal "UTC", account.timezone

    membership = account.memberships.find_by(user_id: @user.id)
    assert membership.present?
    assert_equal "admin", membership.role
    assert membership.active?

    agent = account.agents.find_by(membership_id: membership.id)
    assert agent.present?
    assert_equal "human", agent.kind
    assert agent.active?
    assert_equal "Dora Newcomer", agent.name

    team = account.teams.find_by(name: "General")
    assert team.present?
    assert team.team_memberships.active.exists?(agent:)
  end

  test "same operation key returns the existing Account and never duplicates" do
    first = Accounts::Create.call(user: @user, name: "Marrakech Garden", operation_key: "op-key-same")
    second = Accounts::Create.call(user: @user, name: "Marrakech Garden", operation_key: "op-key-same")

    assert_equal first.id, second.id
    assert_equal 1, Account.where(creation_operation_key: "op-key-same").count
    assert_equal 1, first.memberships.count
    assert_equal 1, first.agents.count
    assert_equal 1, first.teams.count
  end

  test "different operation keys create distinct Accounts" do
    a = Accounts::Create.call(user: @user, name: "One", operation_key: "op-a")
    b = Accounts::Create.call(user: @user, name: "Two", operation_key: "op-b")

    assert_not_equal a.id, b.id
    assert_equal 2, User.find(@user.id).memberships.active.count
  end

  test "invalid name fails with validation errors and writes nothing" do
    account = Accounts::Create.call(user: @user, name: "", operation_key: "op-invalid")
    assert_not account.persisted?
    assert account.errors[:name].any?
    assert_empty Account.where(creation_operation_key: "op-invalid")
  end
end

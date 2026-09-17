require "test_helper"

class Channels::ConnectTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @connection = {
      provider: "instagram", external_id: "ig-123", name: "Reservi",
      provider_config: { "instagram_id" => "ig-123", "username" => "reservi" },
      credentials: { "access_token" => "first-token", "webhook_verify_token" => "verify" }
    }
  end

  test "retry updates the existing provider identity instead of duplicating it" do
    first = Channels::Connect.call(account: @account, connection: @connection)
    retry_connection = @connection.deep_dup
    retry_connection[:credentials]["access_token"] = "refreshed-token"

    assert_no_difference -> { @account.channels.count } do
      second = Channels::Connect.call(account: @account, connection: retry_connection)
      assert_equal first.id, second.id
    end

    assert_equal "refreshed-token", first.reload.credential("access_token")
  end

  test "provider identity cannot be claimed by another account" do
    first = Channels::Connect.call(account: @account, connection: @connection)

    error = assert_raises(Reservi::Errors::OperationError) do
      Channels::Connect.call(account: accounts(:beta), connection: @connection)
    end

    assert_equal @account.id, first.account_id
    assert_match(/already connected/, error.message)
  end
end

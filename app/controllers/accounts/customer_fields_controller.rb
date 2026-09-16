module Accounts
  class CustomerFieldsController < ApplicationController
    before_action :require_account_access!
    before_action :set_customer

    def edit
      @definitions = current_account.field_definitions.active.for_customer
      @customer = @customer
    end

    def update
      CustomerFields::Update.call(
        customer: @customer,
        actor_membership: current_membership,
        attributes: field_params
      )
      redirect_to account_customer_fields_path(current_account, @customer), notice: "Customer updated."
    rescue Reservi::Errors::OperationError => e
      redirect_to edit_account_customer_fields_path(current_account, @customer), alert: e.message
    end

    private

    def set_customer
      @customer = current_account.customers.find(params[:customer_id])
    end

    def field_params
      params.require(:customer).permit(:name, :phone, :email_address, :locale, custom_values: {})
    end
  end
end

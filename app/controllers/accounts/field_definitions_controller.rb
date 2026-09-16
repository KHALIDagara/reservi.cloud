module Accounts
  class FieldDefinitionsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!

    def index
      @definitions = current_account.field_definitions.ordered
    end

    def new
      @definition = current_account.field_definitions.new
    end

    def create
      FieldDefinitions::Create.call(
        account: current_account,
        actor_membership: current_membership,
        attributes: definition_params
      )
      redirect_to account_field_definitions_path(current_account), notice: "Field created."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to new_account_field_definition_path(current_account), alert: e.message
    end

    def archive
      definition = current_account.field_definitions.find(params[:id])
      FieldDefinitions::Archive.call(definition:, actor_membership: current_membership)
      redirect_to account_field_definitions_path(current_account), notice: "Field archived."
    rescue Reservi::Errors::AuthorizationError => e
      redirect_to account_field_definitions_path(current_account), alert: e.message
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage field definitions."
      end
    end

    def definition_params
      params.require(:field_definition).permit(:scope, :key, :label, :field_type, :built_in_binding, :position, options: [], constraints: {})
    end
  end
end

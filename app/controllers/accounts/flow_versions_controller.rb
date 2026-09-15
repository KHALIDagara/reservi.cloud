require "ostruct"

module Accounts
  class FlowVersionsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!
    before_action :set_flow
    before_action :set_version, only: [:show, :edit, :update, :publish, :preview]

    def index
      redirect_to flows_path(current_account)
    end

    def new
      @version = @flow.versions.new
      @version.version_number = next_version_number
      @version.status = "draft"
    end

    def create
      @version = @flow.versions.new(version_params)
      @version.status = "draft"

      if @version.save
        # Clone stages from the current published version if one exists
        if @flow.current_version
          @flow.current_version.stages.each do |stage|
            @version.stages.create!(
              key: stage.key,
              label: stage.label,
              position: stage.position,
              blocks: stage.blocks,
              rules: stage.rules,
              completion: stage.completion
            )
          end
        else
          @version.stages.create!(
            key: "stage_1",
            label: "Stage 1",
            position: 1,
            blocks: [],
            rules: [],
            completion: { "literal" => false }
          )
        end

        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          notice: "Draft version created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      redirect_to edit_flow_flow_version_path(current_account, @flow, @version)
    end

    def edit
      @stages = @version.stages.order(:position)
    end

    def update
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Published versions cannot be edited."
        return
      end

      if @version.update(version_params)
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          notice: "Version updated."
      else
        @stages = @version.stages.order(:position)
        render :edit, status: :unprocessable_entity
      end
    end

    def publish
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Version is already published."
        return
      end

      Flows::Publish.call(flow_version: @version, actor_membership: current_membership)
      redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
        notice: "Flow version published."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
        alert: e.message
    end

    def preview
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Cannot preview a published version."
        return
      end

      @stages = @version.stages.order(:position)
      @synthetic_state = build_synthetic_state
      @evaluations = evaluate_preview
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only administrators can manage flows."
      end
    end

    def set_flow
      @flow = current_account.flows.find(params[:flow_id])
    end

    def set_version
      @version = @flow.versions.find(params[:id])
    end

    def next_version_number
      (@flow.versions.maximum(:version_number) || 0) + 1
    end

    def version_params
      params.require(:flow_version).permit(:version_number)
    end

    def build_synthetic_state
      # Parse submitted preview state or use defaults
      {
        "customer_name" => params.dig(:preview, :customer_name).presence || "Sample Customer",
        "customer_phone" => params.dig(:preview, :phone).presence || "+1 (555) 000-0000",
        "customer_email" => params.dig(:preview, :email).presence || "customer@example.com",
        "customer_city" => params.dig(:preview, :city).presence || "Marrakech",
        "conversation_budget" => params.dig(:preview, :budget).presence || "5000"
      }
    end

    def evaluate_preview
      @stages.each_with_index.map do |stage, index|
        # Build a minimal context from synthetic state
        customer = Customer.new(
          name: @synthetic_state["customer_name"],
          phone: @synthetic_state["customer_phone"],
          email_address: @synthetic_state["customer_email"],
          custom_values: {}
        )
        # Create a minimal conversation-like object for the evaluator
        customer_scope = {
          "name" => customer.name,
          "phone" => customer.phone,
          "email_address" => customer.email_address,
        }
        conversation_custom = { "budget" => @synthetic_state["conversation_budget"] }

        context = {
          customer: customer,
          conversation: OpenStruct.new(
            custom_values: conversation_custom,
            customer: customer,
            owner_id: nil,
            team_id: nil
          ),
          owner_id: nil,
          team_id: nil
        }

        completion = Reservi::PredicateEvaluator.evaluate_with_explanation(
          stage.completion, context
        )

        # Summarize blocks
        block_summary = stage.blocks.map do |b|
          case b["type"]
          when "field" then "Field: #{b['key']}"
          when "catalog" then "Catalog: #{b['catalog_key'] || '?'}"
          when "appointment" then "Appointment"
          else "Block: #{b['type']}"
          end
        end

        # Summarize rules
        rule_summary = (stage.rules || []).map do |r|
          predicate_desc = r["predicate"] ? "(predicate)" : "(always)"
          actions = (r["actions"] || []).map { |a| a["type"] }.join(", ")
          "#{r['key'] || 'rule'} #{predicate_desc} -> #{actions}"
        end

        {
          stage: stage,
          index: index,
          completion: completion,
          blocks: block_summary,
          rules: rule_summary,
          complete: completion[:result]
        }
      end
    end
  end
end
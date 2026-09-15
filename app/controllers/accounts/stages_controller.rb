module Accounts
  class StagesController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!
    before_action :set_flow
    before_action :set_version

    def new
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Cannot modify a published version."
        return
      end

      @stage = @version.stages.new
      @stage.position = next_position
      @stage.key = "stage_#{next_position}"
      @stage.completion = { "literal" => false }
      @stage.blocks = []
      @stage.rules = []
    end

    def create
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Cannot modify a published version."
        return
      end

      @stage = @version.stages.new(stage_params)
      @stage.blocks = parse_blocks
      @stage.rules = parse_rules
      @stage.completion = parse_completion

      if @stage.save
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          notice: "Stage added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Published versions cannot be edited."
        return
      end

      @stage = @version.stages.find(params[:id])
    end

    def update
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Cannot modify a published version."
        return
      end

      @stage = @version.stages.find(params[:id])
      @stage.assign_attributes(stage_params)
      @stage.blocks = parse_blocks
      @stage.rules = parse_rules
      @stage.completion = parse_completion

      if @stage.save
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          notice: "Stage updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @version.published?
        redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
          alert: "Cannot modify a published version."
        return
      end

      stage = @version.stages.find(params[:id])
      stage.destroy!

      # Re-number remaining stages
      @version.stages.order(:position).each_with_index do |s, i|
        s.update_column(:position, i + 1)
      end

      redirect_to edit_flow_flow_version_path(current_account, @flow, @version),
        notice: "Stage removed."
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
      @version = @flow.versions.find(params[:flow_version_id])
    end

    def next_position
      (@version.stages.maximum(:position) || 0) + 1
    end

    def stage_params
      params.require(:stage).permit(:key, :label, :position)
    end

    def parse_blocks
      blocks = []
      raw = params[:blocks] || []

      raw.each do |index, block_params|
        next unless block_params[:type].present?

        entry = { "type" => block_params[:type] }

        case block_params[:type]
        when "field"
          entry["key"] = block_params[:key] if block_params[:key].present?
          entry["required"] = block_params[:required] == "1"
        when "catalog"
          entry["catalog_key"] = block_params[:catalog_key] if block_params[:catalog_key].present?
          entry["role_key"] = block_params[:role_key] if block_params[:role_key].present?
        when "appointment"
          entry["role_key"] = block_params[:role_key] if block_params[:role_key].present?
          entry["duration_minutes"] = block_params[:duration_minutes].to_i if block_params[:duration_minutes].present?
        end

        blocks << entry
      end

      blocks
    end

    def parse_rules
      rules = []
      raw = params[:rules] || []

      raw.each do |index, rule_params|
        next unless rule_params[:key].present?

        entry = { "key" => rule_params[:key] }

        # Parse predicate
        if rule_params[:predicate_type].present?
          entry["predicate"] = build_predicate(rule_params)
        end

        # Parse actions
        entry["actions"] = parse_actions(rule_params[:actions] || {})

        rules << entry
      end

      rules
    end

    def build_predicate(rule_params)
      case rule_params[:predicate_type]
      when "exists"
        { "exists" => { "kind" => "field", "scope" => rule_params[:predicate_scope] || "conversation", "key" => rule_params[:predicate_key] || "" } }
      when "eq"
        { "eq" => { "ref" => { "kind" => "field", "scope" => rule_params[:predicate_scope] || "conversation", "key" => rule_params[:predicate_key] || "" }, "value" => rule_params[:predicate_value] || "" } }
      when "always"
        nil
      when "literal"
        value = rule_params[:predicate_value]
        { "literal" => value == "true" || value == true }
      else
        nil
      end
    end

    def parse_actions(raw)
      actions = []
      raw.each do |index, action_params|
        next unless action_params[:type].present?

        entry = { "type" => action_params[:type] }

        case action_params[:type]
        when "assign"
          entry["agent_name"] = action_params[:agent_name] if action_params[:agent_name].present?
          entry["team_name"] = action_params[:team_name] if action_params[:team_name].present?
        when "send_message"
          entry["template"] = action_params[:template] if action_params[:template].present?
          entry["content"] = action_params[:content] if action_params[:content].present?
        when "create_appointment"
          entry["role_key"] = action_params[:role_key] if action_params[:role_key].present?
          entry["duration_minutes"] = action_params[:duration_minutes].to_i if action_params[:duration_minutes].present?
        when "confirm_appointment", "cancel_appointment"
          entry["role_key"] = action_params[:role_key] if action_params[:role_key].present?
        end

        actions << entry
      end

      actions
    end

    def parse_completion
      raw = params[:completion] || {}
      type = raw[:type]

      case type
      when "literal"
        value = raw[:value]
        { "literal" => value == "true" || value == true }
      when "exists"
        { "exists" => { "kind" => "field", "scope" => raw[:scope] || "conversation", "key" => raw[:key] || "" } }
      when "eq"
        { "eq" => { "ref" => { "kind" => "field", "scope" => raw[:scope] || "conversation", "key" => raw[:key] || "" }, "value" => raw[:value] || "" } }
      when "all"
        # For simplicity in v1, support as nested conditions from form
        conditions = []
        (raw[:conditions] || {}).each do |_, cond|
          next unless cond[:type].present?
          conditions << parse_nested_condition(cond)
        end
        conditions.any? ? { "all" => conditions } : { "literal" => false }
      when "any"
        conditions = []
        (raw[:conditions] || {}).each do |_, cond|
          next unless cond[:type].present?
          conditions << parse_nested_condition(cond)
        end
        conditions.any? ? { "any" => conditions } : { "literal" => false }
      else
        { "literal" => false }
      end
    end

    def parse_nested_condition(cond)
      case cond[:type]
      when "exists"
        { "exists" => { "kind" => cond[:kind] || "field", "scope" => cond[:scope] || "conversation", "key" => cond[:key] || "" } }
      when "eq"
        { "eq" => { "ref" => { "kind" => cond[:kind] || "field", "scope" => cond[:scope] || "conversation", "key" => cond[:key] || "" }, "value" => cond[:value] || "" } }
      when "missing"
        { "missing" => { "kind" => cond[:kind] || "field", "scope" => cond[:scope] || "conversation", "key" => cond[:key] || "" } }
      else
        { "literal" => false }
      end
    end
  end
end
module Accounts
  module Inboxes
    module Conversations
      # The magic side panel for a conversation: fields, catalogs,
      # appointments, assignment, and stage history.
      class PanelController < ApplicationController
        before_action :require_account_access!
        before_action :set_inbox
        before_action :set_conversation

        # GET /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/panel
        def show
          @stage = @conversation.current_stage
          @stage_blocks = @stage&.blocks || []
          load_fields if has_block_type?("field")
          load_catalogs if has_block_type?("catalog")
          load_appointments if has_block_type?("appointment")
          @account_agents = current_account.agents.active.order(:name)

          @stage_history = @conversation.stage_transitions
            .includes(:from_stage, :to_stage)
            .order(created_at: :asc)

          render layout: false
        end

        # GET /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/panel/edit_field
        def edit_field
          scope = params[:scope] || "conversation"
          key   = params[:key]

          @field_definition = current_account.field_definitions.active
            .where(scope:)
            .find_by("key = :key OR built_in_binding = :key", key:)

          unless @field_definition
            render plain: "Field not configured.", status: :not_found and return
          end

          @current_value = if scope == "customer"
            @field_definition.built_in_binding.present? ?
              @conversation.customer.public_send(@field_definition.built_in_binding) :
              @conversation.customer.custom_values[key]
          else
            @conversation.custom_values[key]
          end

          render layout: false
        end

        # PATCH /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/panel/field
        def update_field
          value = typed_field_value(scope: "conversation", key: params[:key], value: params[:value])
          ConversationFields::Update.call(
            conversation: @conversation,
            actor_membership: current_membership,
            attributes: { params[:key] => value }
          )

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace("conversation_panel", partial: "accounts/inboxes/conversations/panel/show",
                  locals: rebuild_panel_locals),
                turbo_stream.replace("conversation_modal", "")
              ]
            end
            format.html { redirect_to conversation_return_path, notice: "Field updated." }
          end
        rescue Reservi::Errors::OperationError => e
          respond_to do |format|
            format.turbo_stream { render turbo_stream: turbo_stream.replace("conversation_modal", partial: "accounts/inboxes/conversations/panel/edit_field_error", locals: { error: e.message }) }
            format.html { redirect_to conversation_return_path, alert: e.message }
          end
        end

        # PATCH /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/panel/customer_field
        def update_customer_field
          value = typed_field_value(scope: "customer", key: params[:key], value: params[:value])
          CustomerFields::Update.call(
            customer: @conversation.customer,
            actor_membership: current_membership,
            attributes: { params[:key] => value }
          )
          Flows::Evaluate.call(conversation: @conversation)

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace("conversation_panel", partial: "accounts/inboxes/conversations/panel/show",
                  locals: rebuild_panel_locals),
                turbo_stream.replace("conversation_modal", "")
              ]
            end
            format.html { redirect_to conversation_return_path, notice: "Customer field updated." }
          end
        rescue Reservi::Errors::OperationError => e
          respond_to do |format|
            format.turbo_stream { render turbo_stream: turbo_stream.replace("conversation_modal", partial: "accounts/inboxes/conversations/panel/edit_field_error", locals: { error: e.message }) }
            format.html { redirect_to conversation_return_path, alert: e.message }
          end
        end

        private

        def set_inbox
          @inbox = current_account.channels.find(params[:inbox_id])
        end

        def set_conversation
          @conversation = @inbox.conversations.find(params[:conversation_id])
        rescue ActiveRecord::RecordNotFound
          redirect_to account_inbox_path(current_account), alert: "Conversation not found."
        end

        def conversation_return_path
          account_inbox_conversation_url(current_account, params[:inbox_id], @conversation)
        end

        def has_block_type?(type)
          @stage_blocks.any? { |b| b["type"] == type }
        end

        def typed_field_value(scope:, key:, value:)
          definition = current_account.field_definitions.active
            .where(scope:)
            .find_by("key = :key OR built_in_binding = :key", key: key)
          raise Reservi::Errors::OperationError, "That field is not configured." unless definition
          unless Array(@conversation.current_stage&.blocks).any? { |b| b["type"] == "field" && b["key"] == definition.key }
            raise Reservi::Errors::OperationError, "That field is not available in the current stage."
          end
          return nil if value.blank? && definition.field_type != "multi_choice"
          case definition.field_type
          when "number"
            number = BigDecimal(value.to_s)
            number.frac.zero? ? number.to_i : number.to_f
          when "boolean"
            ActiveModel::Type::Boolean.new.cast(value)
          when "multi_choice"
            Array(value).reject(&:blank?)
          else value
          end
        rescue ArgumentError
          value
        end

        def rebuild_panel_locals
          @conversation.reload
          @stage = @conversation.current_stage
          @stage_blocks = @stage&.blocks || []
          load_fields if has_block_type?("field")
          load_catalogs if has_block_type?("catalog")
          load_appointments if has_block_type?("appointment")
          @account_agents = current_account.agents.active.order(:name)
          @stage_history = @conversation.stage_transitions
            .includes(:from_stage, :to_stage)
            .order(created_at: :asc)

          {
            stage: @stage,
            conversation: @conversation,
            stage_blocks: @stage_blocks,
            customer_fields: @customer_fields,
            conversation_fields: @conversation_fields,
            catalogs: @catalogs,
            item_selections: @item_selections,
            catalog_roles: @catalog_roles,
            appointments: @appointments,
            account_agents: @account_agents,
            stage_history: @stage_history
          }
        end

        def load_fields
          field_keys = @stage_blocks.select { |b| b["type"] == "field" }.map { |b| b["key"] }.compact
          return if field_keys.empty?
          @field_definitions = current_account.field_definitions.active
            .where(scope: %w[customer conversation], key: field_keys)
            .ordered
          @customer_fields = {}
          @conversation_fields = {}
          @field_definitions.each do |fd|
            key = fd.key
            if fd.scope == "customer"
              value = fd.built_in_binding.present? ? @conversation.customer.public_send(fd.built_in_binding) : @conversation.customer.custom_values[key]
              @customer_fields[key] = { definition: fd, value: }
            else
              @conversation_fields[key] = { definition: fd, value: @conversation.custom_values[key] }
            end
          end
        end

        def load_catalogs
          catalog_blocks = @stage_blocks.select { |b| b["type"] == "catalog" && b["catalog_key"].present? }
          return if catalog_blocks.empty?
          catalog_keys = catalog_blocks.map { |b| b["catalog_key"] }.uniq
          @catalogs = current_account.catalogs.active
            .where("LOWER(title) IN (?)", catalog_keys.map(&:downcase))
            .includes(:items)
          @item_selections = @conversation.item_selections.index_by(&:role_key)
          @catalog_roles = {}
          catalog_blocks.each do |b|
            next unless b["role_key"].present? && b["catalog_key"].present?
            @catalog_roles[b["role_key"]] = b["catalog_key"]
          end
        end

        def load_appointments
          appointment_blocks = @stage_blocks.select { |b| b["type"] == "appointment" && b["role_key"].present? }
          return if appointment_blocks.empty?
          role_keys = appointment_blocks.map { |b| b["role_key"] }
          @appointments = @conversation.appointments
            .where(role_key: role_keys)
            .where("superseded_by_id IS NULL OR superseded_by_id = 0")
            .index_by(&:role_key)
        end
      end
    end
  end
end
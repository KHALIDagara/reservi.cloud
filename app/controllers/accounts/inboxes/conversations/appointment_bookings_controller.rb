module Accounts
  module Inboxes
    module Conversations
      # Appointment booking modal for a conversation within an inbox.
      # Agent → day → slot → confirm flow.
      class AppointmentBookingsController < ApplicationController
        before_action :require_account_access!
        before_action :set_inbox
        before_action :set_conversation

        # GET /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/appointment_booking?role_key=&step=
        def show
          @role_key = params[:role_key]
          return head :not_found unless @role_key.present?

          stage = @conversation.current_stage
          appointment_block = stage&.blocks&.find { |b| b["type"] == "appointment" && b["role_key"] == @role_key }
          return head :not_found unless appointment_block

          @step = params[:step] || "agent"
          @schedulable_agents = current_account.agents.assignable.human.schedulable.order(:name)
          @existing = @conversation.appointments.current.for_role(@role_key).first

          case @step
          when "agent"
            render_agent_step
          when "day"
            render_day_step
          when "confirm"
            render_confirm_step
          else
            render_agent_step
          end
        rescue => e
          render plain: e.message, status: :unprocessable_content
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/appointment_booking
        def create
          role_key = params[:role_key]
          agent_id = params[:agent_id].to_i
          starts_at_value = params[:starts_at]
          duration = (params[:duration] || 60).to_i

          stage = @conversation.current_stage
          appointment_block = stage&.blocks&.find { |b| b["type"] == "appointment" && b["role_key"] == role_key }
          return head :not_found unless appointment_block

          scheduled_agent = current_account.agents.assignable.human.schedulable.find_by(id: agent_id)
          return head :not_found unless scheduled_agent

          starts_at = Time.zone.parse(starts_at_value.to_s)
          return head :unprocessable_content unless starts_at

          ends_at = starts_at + duration.minutes

          appointment = Appointments::Create.call(
            conversation: @conversation,
            role_key:,
            starts_at:,
            ends_at:,
            timezone: current_account.timezone,
            scheduled_agent:
          )

          Flows::Evaluate.call(conversation: @conversation)

          @conversation.reload
          publish_conversation_changed(@conversation, :appointment_changed)

          render turbo_stream: [
            turbo_stream.replace("conversation_panel", partial: "accounts/inboxes/conversations/panel/show",
              locals: rebuild_panel_locals),
            turbo_stream.update("conversation_modal", ""),
            turbo_stream.action(:dispatch_event, "modal:close", { bubbles: true, cancelable: false })
          ]
        rescue Reservi::Errors::OperationError => e
          render turbo_stream: turbo_stream.replace("conversation_modal",
            partial: "accounts/inboxes/conversations/panel/edit_field_error",
            locals: { error: e.message })
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

        def render_agent_step
          render "accounts/inboxes/conversations/appointment_bookings/agent_step", layout: false
        end

        def render_day_step
          @selected_agent = current_account.agents.assignable.human.schedulable.find_by(id: params[:agent_id])
          return head :not_found unless @selected_agent

          # Show next 14 days
          @available_days = (0..13).map { |i| Date.current + i.days }

          render "accounts/inboxes/conversations/appointment_bookings/day_step", layout: false
        end

        def render_confirm_step
          @selected_agent = current_account.agents.assignable.human.schedulable.find_by(id: params[:agent_id])
          return head :not_found unless @selected_agent

          @selected_date = Date.parse(params[:date].to_s) rescue Date.current
          @selected_slot = params[:slot] || "09:00"
          @starts_at = Time.zone.parse("#{@selected_date} #{@selected_slot}", current_account.timezone)
          @duration = (params[:duration] || 60).to_i

          render "accounts/inboxes/conversations/appointment_bookings/confirm_step", layout: false
        end

        def publish_conversation_changed(conversation, event)
          return unless conversation&.persisted?
          Realtime::ConversationChangedJob.perform_later(
            account_id:      conversation.account_id,
            conversation_id: conversation.id,
            revision:        conversation.revision,
            event:
          )
        end

        def rebuild_panel_locals
          @conversation.reload
          ::Realtime::ConversationChangedJob::AccountPanelLoader.new(@conversation).call
        end
      end
    end
  end
end
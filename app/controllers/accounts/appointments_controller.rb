module Accounts
  # Collaborative Appointment Scheduling controller.
  #
  # Provides endpoints for:
  #   - Listing schedulable agents (for an agent-picker dropdown)
  #   - Querying availability (available days + time slots per agent)
  #   - Booking a confirmed appointment
  #   - Changing appointment status
  #   - Reassigning an appointment to a different agent
  #   - Rescheduling an appointment (owner only)
  #   - Taking over a conversation from an appointment context
  #
  # All endpoints use the new stable domain operations (Appointments::Book,
  # Appointments::ChangeStatus, Appointments::Reassign, Appointments::Reschedule,
  # Conversations::Takeover).
  class AppointmentsController < ApplicationController
    before_action :require_account_access!
    before_action :set_conversation_for_booking, only: %i[book takeover_conversation]
    before_action :set_appointment, only: %i[change_status reassign reschedule]

    # GET  /a/:account_id/appointments/agents
    # Returns a JSON list of schedulable Agents for the account.
    # Each entry includes basic info suitable for an agent-picker UI.
    def agents
      agents = current_account.agents.schedulable.order(:name)
      render json: {
        agents: agents.map { |a|
          {
            id:   a.id,
            name: a.name,
            avatar_url: helpers.avatar_for_agent(a)
          }
        }
      }
    end

    # GET  /a/:account_id/appointments/availability
    # Query params: agent_id, date, duration_minutes, exclude_appointment_id
    # Returns available_days calendar + available slots for the requested date.
    def availability
      agent = current_account.agents.schedulable.find_by(id: params[:agent_id])
      unless agent
        render json: { error: "Agent not schedulable" }, status: :not_found and return
      end

      setting = agent.calendar_setting
      unless setting
        render json: { available_days: [], available_slots: [] } and return
      end

      duration = (params[:duration_minutes].presence || 60).to_i

      # Available upcoming days
      available_days = setting.available_days.map { |d|
        d.strftime("%Y-%m-%d")
      }

      # Available slots for a specific date
      available_slots = []
      if params[:date].present?
        date = Date.parse(params[:date].to_s) rescue nil
        if date
          exclude_id = params[:exclude_appointment_id].presence
          exclude_appt = exclude_id ? Appointment.find_by(id: exclude_id) : nil
          available_slots = setting.available_slots(
            date: date,
            duration_minutes: duration,
            excluding_appointment: exclude_appt
          ).map { |t| t.iso8601 }
        end
      end

      render json: {
        available_days:  available_days,
        available_slots: available_slots
      }
    end

    # POST /a/:account_id/conversations/:conversation_id/appointments/:id/book
    # Books a confirmed appointment using the collaborative-scheduling flow.
    def book
      agent = current_membership.agent

      Appointments::Book.call(
        conversation:     @conversation,
        actor:            agent,
        scheduled_agent:  current_account.agents.schedulable.find_by!(id: params[:scheduled_agent_id]),
        role_key:         params[:role_key],
        starts_at:        Time.iso8601(params[:starts_at]),
        duration_minutes: params.fetch(:duration_minutes, 60).to_i,
        operation_key:    params[:operation_key].presence,
        purpose:          params[:purpose].presence
      )

      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation),
        notice: "Appointment booked."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation, panel: "open"),
        alert: e.message
    end

    # POST /a/:account_id/appointments/:id/change_status
    def change_status
      Appointments::ChangeStatus.call(
        appointment:      @appointment,
        actor:            current_membership.agent,
        status:           params[:status],
        reason:           params[:reason].presence,
        expected_version: params[:lock_version].presence&.to_i
      )

      conv = @appointment.conversation
      Flows::Evaluate.call(conversation: conv)
      redirect_to account_conversation_path(current_account, conv),
        notice: "Appointment #{params[:status]}."
    rescue Reservi::Errors::OperationError => e
      conv = @appointment.conversation
      redirect_to account_conversation_path(current_account, conv),
        alert: e.message
    end

    # POST /a/:account_id/appointments/:id/reassign
    def reassign
      new_agent = current_account.agents.schedulable.find_by!(id: params[:scheduled_agent_id])
      Appointments::Reassign.call(
        appointment:      @appointment,
        actor:            current_membership.agent,
        scheduled_agent:  new_agent,
        expected_version: params[:lock_version].presence&.to_i
      )

      conv = @appointment.conversation
      redirect_to account_conversation_path(current_account, conv),
        notice: "Appointment reassigned to #{new_agent.name}."
    rescue Reservi::Errors::OperationError => e
      conv = @appointment.conversation
      redirect_to account_conversation_path(current_account, conv),
        alert: e.message
    end

    # POST /a/:account_id/appointments/:id/reschedule
    def reschedule
      Appointments::Reschedule.call(
        appointment:      @appointment,
        actor:            current_membership.agent,
        starts_at:        Time.iso8601(params[:starts_at]),
        duration_minutes: params.fetch(:duration_minutes, 60).to_i,
        expected_version: params[:lock_version].presence&.to_i
      )

      conv = @appointment.conversation
      redirect_to account_conversation_path(current_account, conv),
        notice: "Appointment rescheduled."
    rescue Reservi::Errors::OperationError => e
      conv = @appointment.conversation
      redirect_to account_conversation_path(current_account, conv),
        alert: e.message
    end

    # POST /a/:account_id/conversations/:conversation_id/appointments/:id/takeover_conversation
    def takeover_conversation
      Conversations::Takeover.call(
        conversation: @conversation,
        actor:        current_membership.agent
      )

      redirect_to account_conversation_path(current_account, @conversation),
        notice: "Conversation claimed."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation),
        alert: e.message
    end

    private

    def set_conversation_for_booking
      conv_id = params[:conversation_id]
      @conversation = current_account.conversations.find(conv_id)
    rescue ActiveRecord::RecordNotFound
      redirect_to account_inbox_path(current_account), alert: "Conversation not found."
    end

    def set_appointment
      @appointment = current_account.appointments.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to account_inbox_path(current_account), alert: "Appointment not found."
    end
  end
end
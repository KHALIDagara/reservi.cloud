module Reservi
  # OpenAI-compatible function definitions for every tool available to
  # an AI agent.  Used by the AI provider adapter to tell the LLM which
  # tools it may call and how to structure their arguments.
  class AiToolSchema
    # Return OpenAI-compatible function definitions for all available tools.
    def self.function_definitions(agent:)
      base_tools = [
        read_workspace_def,
        create_message_def, create_note_def,
        update_field_def, select_item_def,
        create_appointment_def, confirm_appointment_def,
        cancel_appointment_def, handoff_def
      ]

      # Include search_knowledge for all agents — the tool itself
      # returns a placeholder until the knowledge system is built (T11+).
      base_tools.unshift(search_knowledge_def)

      base_tools
    end

    # Validate that proposed tool calls are within schema bounds.
    # Returns an array of error strings (empty means all valid).
    def self.validate_tool_calls(tool_calls, agent:)
      valid_names = function_definitions(agent: agent).map { |d| d.dig(:function, :name) }
      errors = []

      tool_calls.each do |call|
        name      = call.is_a?(Hash) ? (call["name"] || call[:name]) : nil
        arguments = call.is_a?(Hash) ? (call["arguments"] || call[:arguments]) : nil

        unless valid_names.include?(name)
          errors << "Unknown tool: #{name}"
          next
        end

        if arguments.is_a?(String) && arguments.present?
          begin
            JSON.parse(arguments)
          rescue JSON::ParserError
            errors << "Invalid JSON arguments for tool: #{name}"
          end
        end
      end

      errors
    end

    private

    def self.read_workspace_def
      {
        type: "function",
        function: {
          name:        "read_workspace",
          description: "Read the full current workspace snapshot including conversation state, stage requirements, customer facts, items, appointments, and recent messages",
          parameters:  { type: "object", properties: {} }
        }
      }
    end

    def self.search_knowledge_def
      {
        type: "function",
        function: {
          name:        "search_knowledge",
          description: "Search the knowledge base for relevant information",
          parameters: {
            type:       "object",
            properties: {
              query: { type: "string", description: "Search query" }
            },
            required: [ "query" ]
          }
        }
      }
    end

    def self.create_message_def
      {
        type: "function",
        function: {
          name:        "create_message",
          description: "Send a message to the customer",
          parameters: {
            type:       "object",
            properties: {
              content: { type: "string", description: "Message text" }
            },
            required: [ "content" ]
          }
        }
      }
    end

    def self.create_note_def
      {
        type: "function",
        function: {
          name:        "create_note",
          description: "Add an internal note (not visible to customer)",
          parameters: {
            type:       "object",
            properties: {
              content: { type: "string", description: "Note text" }
            },
            required: [ "content" ]
          }
        }
      }
    end

    def self.update_field_def
      {
        type: "function",
        function: {
          name:        "update_field",
          description: "Update a field value on the customer or conversation",
          parameters: {
            type:       "object",
            properties: {
              scope: { type: "string", enum: %w[customer conversation] },
              key:   { type: "string" },
              value: { type: "string" }
            },
            required: %w[scope key value]
          }
        }
      }
    end

    def self.select_item_def
      {
        type: "function",
        function: {
          name:        "select_item",
          description: "Select an item from a catalog for this conversation",
          parameters: {
            type:       "object",
            properties: {
              role_key: { type: "string" },
              item_id:  { type: "integer" }
            },
            required: %w[role_key item_id]
          }
        }
      }
    end

    def self.create_appointment_def
      {
        type: "function",
        function: {
          name:        "create_appointment",
          description: "Create a new appointment",
          parameters: {
            type:       "object",
            properties: {
              role_key:  { type: "string" },
              starts_at: { type: "string" },
              ends_at:   { type: "string" }
            },
            required: %w[role_key starts_at]
          }
        }
      }
    end

    def self.confirm_appointment_def
      {
        type: "function",
        function: {
          name:        "confirm_appointment",
          description: "Confirm a pending appointment",
          parameters: {
            type:       "object",
            properties: {
              role_key: { type: "string" }
            },
            required: [ "role_key" ]
          }
        }
      }
    end

    def self.cancel_appointment_def
      {
        type: "function",
        function: {
          name:        "cancel_appointment",
          description: "Cancel an appointment",
          parameters: {
            type:       "object",
            properties: {
              role_key: { type: "string" }
            },
            required: [ "role_key" ]
          }
        }
      }
    end

    def self.handoff_def
      {
        type: "function",
        function: {
          name:        "handoff",
          description: "Handoff the conversation to a human agent",
          parameters: {
            type:       "object",
            properties: {
              reason: { type: "string" }
            },
            required: []
          }
        }
      }
    end
  end
end

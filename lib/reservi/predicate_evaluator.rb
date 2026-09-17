module Reservi
  # Evaluates structured predicates against a Conversation context.
  # Predicates are plain hashes — no arbitrary code execution.
  #
  # context: {
  #   customer: Customer record,
  #   conversation: Conversation record,
  #   owner_id: Integer or nil,
  #   team_id: Integer or nil,
  #   field_definitions: Hash { scope => { key => definition } } indexed for fast lookup
  # }
  class PredicateEvaluator
    def self.evaluate(predicate, context)
      new(predicate, context).evaluate
    end

    def initialize(predicate, context)
      @predicate = predicate
      @context = context
    end

    def evaluate
      return evaluate_node(@predicate) if @predicate.is_a?(Hash)
      false
    end

    # Returns an explanation tree: { result: true/false, reason: "string", children: [...] }
    def self.evaluate_with_explanation(predicate, context)
      new(predicate, context).evaluate_with_explanation
    end

    def evaluate_with_explanation
      explain_node(@predicate)
    end

    private

    def evaluate_node(node)
      return false unless node.is_a?(Hash)

      op = node.keys.first
      args = node[op]

      case op
      when "literal" then !!args
      when "exists" then resolve_ref(args).present?
      when "missing" then resolve_ref(args).blank?
      when "eq" then evaluate_eq(args)
      when "neq" then !evaluate_eq(args)
      when "gt" then evaluate_comparison(args) { |a, b| a.is_a?(Numeric) && b.is_a?(Numeric) && a > b }
      when "gte" then evaluate_comparison(args) { |a, b| a.is_a?(Numeric) && b.is_a?(Numeric) && a >= b }
      when "lt" then evaluate_comparison(args) { |a, b| a.is_a?(Numeric) && b.is_a?(Numeric) && a < b }
      when "lte" then evaluate_comparison(args) { |a, b| a.is_a?(Numeric) && b.is_a?(Numeric) && a <= b }
      when "all" then args.is_a?(Array) && args.all? { |sub| evaluate_node(sub) }
      when "any" then args.is_a?(Array) && args.any? { |sub| evaluate_node(sub) }
      when "not" then !evaluate_node(args)
      else false
      end
    end

    def evaluate_eq(args)
      return false unless args.is_a?(Hash) && args.key?("ref") && args.key?("value")
      resolved = resolve_ref(args["ref"])
      return false if resolved.nil?  # missing never eq

      # Compare as strings by default, preserve numeric comparison
      expected = args["value"]
      if resolved.is_a?(Numeric) && expected.is_a?(Numeric)
        resolved == expected
      else
        resolved.to_s == expected.to_s
      end
    end

    def evaluate_comparison(args)
      return false unless args.is_a?(Hash) && args.key?("ref") && args.key?("value")
      resolved = resolve_ref(args["ref"])
      return false if resolved.nil?  # missing never gt/lt etc

      yield(resolved, args["value"])
    end

    def resolve_ref(ref)
      return nil unless ref.is_a?(Hash)

      case ref["kind"]
      when "field"
        resolve_field(ref["scope"], ref["key"])
      when "owner"
        @context[:owner_id]
      when "team"
        @context[:team_id]
      when "item_selection"
        resolve_item_selection(ref)
      when "appointment"
        resolve_appointment(ref)
      else
        nil
      end
    end

    def resolve_item_selection(ref)
      conversation = @context[:conversation]
      role_key = ref["key"] || ref["role_key"]
      return nil unless conversation && role_key.present?

      selections = conversation.item_selections.for_role(role_key)
      case ref["attribute"]
      when "count" then selections.count
      when "item_id" then selections.order(:id).pick(:item_id)
      else selections.exists? ? true : nil
      end
    end

    def resolve_appointment(ref)
      conversation = @context[:conversation]
      role_key = ref["key"] || ref["role_key"]
      return nil unless conversation && role_key.present?

      appointment = conversation.appointments.current.for_role(role_key).first
      return nil unless appointment

      case ref["attribute"]
      when "status" then appointment.status
      when "starts_at" then appointment.starts_at
      when "ends_at" then appointment.ends_at
      else true
      end
    end

    def resolve_field(scope, key)
      case scope
      when "customer"
        customer = @context[:customer]
        return nil unless customer
        if %w[name phone email_address locale].include?(key)
          customer.public_send(key)
        else
          customer.custom_values[key]
        end
      when "conversation"
        conversation = @context[:conversation]
        return nil unless conversation
        conversation.custom_values[key]
      else
        nil
      end
    end

    def explain_node(node)
      return { result: false, reason: "Invalid predicate" } unless node.is_a?(Hash)

      op = node.keys.first
      args = node[op]
      result = evaluate_node(node)

      case op
      when "literal"
        { result: result, reason: "Literal #{args}" }
      when "exists"
        ref_desc = describe_ref(args)
        val = resolve_ref(args)
        if val.present?
          { result: true, reason: "#{ref_desc} exists (#{val})" }
        else
          { result: false, reason: "#{ref_desc} is missing" }
        end
      when "missing"
        ref_desc = describe_ref(args)
        val = resolve_ref(args)
        if val.blank?
          { result: true, reason: "#{ref_desc} is missing" }
        else
          { result: false, reason: "#{ref_desc} exists (#{val})" }
        end
      when "eq"
        ref_desc = describe_ref(args["ref"])
        expected = args["value"]
        if result
          { result: true, reason: "#{ref_desc} equals #{expected}" }
        else
          { result: false, reason: "#{ref_desc} does not equal #{expected}" }
        end
      when "neq"
        ref_desc = describe_ref(args["ref"])
        expected = args["value"]
        if result
          { result: true, reason: "#{ref_desc} does not equal #{expected}" }
        else
          { result: false, reason: "#{ref_desc} equals #{expected}" }
        end
      when "gt", "gte", "lt", "lte"
        ref_desc = describe_ref(args["ref"])
        expected = args["value"]
        op_name = { "gt" => ">", "gte" => ">=", "lt" => "<", "lte" => "<=" }[op]
        if result
          { result: true, reason: "#{ref_desc} #{op_name} #{expected}" }
        else
          { result: false, reason: "#{ref_desc} is not #{op_name} #{expected}" }
        end
      when "all"
        children = args.map { |sub| explain_node(sub) }
        { result: children.all? { |c| c[:result] }, reason: "All conditions", children: children }
      when "any"
        children = args.map { |sub| explain_node(sub) }
        { result: children.any? { |c| c[:result] }, reason: "Any condition", children: children }
      when "not"
        child = explain_node(args)
        { result: !child[:result], reason: "Not", children: [ child ] }
      else
        { result: false, reason: "Unknown operator: #{op}" }
      end
    end

    def describe_ref(ref)
      return "unknown reference" unless ref.is_a?(Hash)
      case ref["kind"]
      when "field" then "Field #{ref['scope']}.#{ref['key']}"
      when "owner" then "Owner"
      when "team" then "Team"
      when "item_selection" then "Item selection #{ref['key'] || ref['role_key']}#{".#{ref['attribute']}" if ref['attribute'].present?}"
      when "appointment" then "Appointment #{ref['key'] || ref['role_key']}#{".#{ref['attribute']}" if ref['attribute'].present?}"
      else "Reference #{ref['kind']}"
      end
    end
  end
end

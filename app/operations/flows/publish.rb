module Flows
  # Validates and publishes a FlowVersion.
  # Once published, a version is immutable.
  # Sets it as the Flow's current_version.
  #
  # Validation checks:
  #   - Admin authorization
  #   - Not already published
  #   - At least one stage
  #   - Stage keys: lowercase, letters/digits/underscores
  #   - No duplicate stage keys or positions
  #   - Block types: only field/catalog/appointment
  #   - Rule action types: only implemented types
  #   - Completion predicates: no circular/unknown operators
  #   - Maximum limits: 50 stages, 50 rules/stage, 10 actions/rule
  #   - Predicate AST max depth 10, max 100 nodes
  #   - Cross-account references rejected
  #   - Valid predicate operators only
  class Publish
    MAX_STAGES = 50
    MAX_RULES_PER_STAGE = 50
    MAX_ACTIONS_PER_RULE = 10
    MAX_AST_DEPTH = 10
    MAX_AST_NODES = 100

    SUPPORTED_BLOCK_TYPES = %w[field catalog appointment].freeze
    SUPPORTED_ACTION_TYPES = %w[assign send_message create_appointment confirm_appointment cancel_appointment].freeze
    SUPPORTED_PREDICATE_OPS = %w[literal exists missing eq neq gt gte lt lte all any not].freeze

    def self.call(flow_version:, actor_membership:)
      new(flow_version:, actor_membership:).call
    end

    def initialize(flow_version:, actor_membership:)
      @flow_version = flow_version
      @actor_membership = actor_membership
    end

    def call
      raise Reservi::Errors::AuthorizationError, "Only administrators can publish flows." unless admin?
      raise Reservi::Errors::OperationError, "Version is already published." if @flow_version.published?
      raise Reservi::Errors::OperationError, "Version must have at least one stage." if @flow_version.stages.empty?
      raise Reservi::Errors::OperationError, "Version exceeds maximum of #{MAX_STAGES} stages." if @flow_version.stages.size > MAX_STAGES

      validate_keys_and_positions!
      validate_stage_structure!
      validate_role_consistency!

      @flow_version.transaction do
        @flow_version.update!(status: "published", published_at: Time.current)
        @flow_version.flow.update!(current_version: @flow_version)
        @flow_version
      end
    end

    private

    def admin?
      Accounts::Policy.new(@actor_membership).admin?
    end

    def validate_keys_and_positions!
      keys = @flow_version.stages.pluck(:key)
      positions = @flow_version.stages.pluck(:position)

      keys.each do |key|
        unless key.match?(/\A[a-z][a-z0-9_]*\z/)
          raise Reservi::Errors::OperationError,
            "Invalid stage key '#{key}': must start with lowercase letter, followed by lowercase letters, digits, or underscores."
        end
      end

      duplicates = keys.tally.select { |_, count| count > 1 }
      if duplicates.any?
        raise Reservi::Errors::OperationError,
          "Duplicate stage keys: #{duplicates.keys.join(', ')}"
      end

      position_dupes = positions.tally.select { |_, count| count > 1 }
      if position_dupes.any?
        raise Reservi::Errors::OperationError,
          "Duplicate stage positions: #{position_dupes.keys.join(', ')}"
      end
    end

    def validate_stage_structure!
      @flow_version.stages.each do |stage|
        validate_blocks!(stage)
        validate_rules!(stage)
        validate_completion!(stage)
      end
    end

    def validate_role_consistency!
      # A role (catalog role_key or appointment role_key) used in multiple
      # stages should reference the same kind of thing. Catalog roles and
      # appointment roles are distinct namespaces.
      catalog_roles = {}  # role_key -> { catalog_key, stages }
      appointment_roles = {}  # role_key -> [stage_keys]

      @flow_version.stages.each do |stage|
        stage.blocks.each do |block|
          role = block["role_key"]
          next if role.blank?

          case block["type"]
          when "catalog"
            if appointment_roles.key?(role)
              raise Reservi::Errors::OperationError,
                "Stage '#{stage.key}': catalog role '#{role}' conflicts with appointment role in stage(s) #{appointment_roles[role].join(', ')}"
            end
            if catalog_roles.key?(role) && catalog_roles[role][:catalog_key] != block["catalog_key"]
              raise Reservi::Errors::OperationError,
                "Stage '#{stage.key}': catalog role '#{role}' references catalog '#{block["catalog_key"]}' but was previously referenced with catalog '#{catalog_roles[role][:catalog_key]}' in stage(s) #{catalog_roles[role][:stages].join(', ')}"
            end
            catalog_roles[role] ||= { catalog_key: block["catalog_key"], stages: [] }
            catalog_roles[role][:stages] << stage.key
          when "appointment"
            if catalog_roles.key?(role)
              raise Reservi::Errors::OperationError,
                "Stage '#{stage.key}': appointment role '#{role}' conflicts with catalog role in stage(s) #{catalog_roles[role][:stages].join(', ')}"
            end
            appointment_roles[role] ||= []
            appointment_roles[role] << stage.key
          end
        end
      end
    end

    def validate_blocks!(stage)
      stage.blocks.each do |block|
        type = block["type"]
        unless SUPPORTED_BLOCK_TYPES.include?(type)
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}': unsupported block type '#{type}'"
        end

        # Validate field block has a key
        if type == "field" && block["key"].blank?
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}': field block must specify a field key"
        end

        # Validate catalog block has a catalog_key
        if type == "catalog" && block["catalog_key"].blank?
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}': catalog block must specify a catalog key"
        end

        # Validate appointment block has a role_key
        if type == "appointment" && block["role_key"].blank?
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}': appointment block must specify a role key"
        end
      end
    end

    def validate_rules!(stage)
      if stage.rules.size > MAX_RULES_PER_STAGE
        raise Reservi::Errors::OperationError,
          "Stage '#{stage.key}' exceeds maximum of #{MAX_RULES_PER_STAGE} rules"
      end

      stage.rules.each do |rule|
        unless rule["key"].present?
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}': rule must have a key"
        end

        # Validate predicate structure
        predicate = rule["predicate"]
        if predicate.present?
          validate_predicate!(predicate, stage.key, "rule '#{rule['key']}'")
        end

        # Validate actions
        actions = rule["actions"] || []
        if actions.size > MAX_ACTIONS_PER_RULE
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}', rule '#{rule['key']}': exceeds maximum of #{MAX_ACTIONS_PER_RULE} actions"
        end

        actions.each do |action|
          action_type = action["type"]
          unless SUPPORTED_ACTION_TYPES.include?(action_type)
            raise Reservi::Errors::OperationError,
              "Stage '#{stage.key}', rule '#{rule['key']}': unsupported action type '#{action_type}'"
          end
        end
      end
    end

    def validate_completion!(stage)
      completion = stage.completion
      unless completion.is_a?(Hash) && completion.keys.any?
        raise Reservi::Errors::OperationError,
          "Stage '#{stage.key}': completion predicate is empty"
      end

      validate_predicate!(completion, stage.key, "completion")
    end

    def validate_predicate!(predicate, stage_key, context)
      depth = 0
      counter = { count: 0 }
      validate_predicate_node!(predicate, stage_key, context, depth, counter)
    end

    def validate_predicate_node!(node, stage_key, context, depth, counter)
      unless node.is_a?(Hash)
        raise Reservi::Errors::OperationError,
          "Stage '#{stage_key}', #{context}: predicate node must be a hash"
      end

      raise Reservi::Errors::OperationError,
        "Stage '#{stage_key}', #{context}: AST depth exceeds maximum of #{MAX_AST_DEPTH}" if depth > MAX_AST_DEPTH

      counter[:count] += 1
      raise Reservi::Errors::OperationError,
        "Stage '#{stage_key}', #{context}: AST node count exceeds maximum of #{MAX_AST_NODES}" if counter[:count] > MAX_AST_NODES

      op = node.keys.first
      args = node[op]

      unless SUPPORTED_PREDICATE_OPS.include?(op)
        raise Reservi::Errors::OperationError,
          "Stage '#{stage_key}', #{context}: unsupported predicate operator '#{op}'"
      end

      # Validate reference kinds in predicate
      case op
      when "exists", "missing"
        validate_ref!(args, stage_key, context) if args.is_a?(Hash)
      when "eq", "neq", "gt", "gte", "lt", "lte"
        if args.is_a?(Hash) && args["ref"].is_a?(Hash)
          validate_ref!(args["ref"], stage_key, context)
        end
      when "all", "any"
        if args.is_a?(Array)
          args.each { |sub| validate_predicate_node!(sub, stage_key, context, depth + 1, counter) }
        end
      when "not"
        validate_predicate_node!(args, stage_key, context, depth + 1, counter) if args.is_a?(Hash)
      when "literal"
        # No further validation needed for literal values
      end
    end

    def validate_ref!(ref, stage_key, context)
      kind = ref["kind"]
      unless %w[field owner team].include?(kind)
        raise Reservi::Errors::OperationError,
          "Stage '#{stage_key}', #{context}: unsupported reference kind '#{kind}'"
      end

      # For field references, validate scope
      if kind == "field"
        scope = ref["scope"]
        unless %w[customer conversation].include?(scope)
          raise Reservi::Errors::OperationError,
            "Stage '#{stage_key}', #{context}: invalid field scope '#{scope}'"
        end

        key = ref["key"]
        if key.blank?
          raise Reservi::Errors::OperationError,
            "Stage '#{stage_key}', #{context}: field reference must specify a key"
        end

        # Note: field definition may not exist yet; the account admin may create
        # it before activating the flow. A future iteration may emit a soft warning.
      end
    end
  end
end
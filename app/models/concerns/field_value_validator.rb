module FieldValueValidator
  # Validates a hash of { key => value } against a collection of FieldDefinitions.
  # Returns { valid: bool, errors: { key => [messages] } }
  def self.validate_values(values, definitions)
    errors = {}
    definitions_by_key = definitions.index_by(&:key)

    values.each do |key, value|
      defn = definitions_by_key[key]
      next unless defn

      field_errors = validate_one(value, defn)
      errors[key] = field_errors if field_errors.any?
    end

    { valid: errors.empty?, errors: errors }
  end

  def self.validate_one(value, definition)
    errors = []
    return errors if value.nil? # nil = unset, allowed

    case definition.field_type
    when "text"
      errors << "Must be a string" unless value.is_a?(String)
    when "number"
      errors << "Must be a number" unless value.is_a?(Integer) || value.is_a?(Float)
      if definition.constraints["min"] && value.to_f < definition.constraints["min"].to_f
        errors << "Must be at least #{definition.constraints['min']}"
      end
      if definition.constraints["max"] && value.to_f > definition.constraints["max"].to_f
        errors << "Must be at most #{definition.constraints['max']}"
      end
    when "boolean"
      errors << "Must be true or false" unless [ true, false ].include?(value)
    when "single_choice"
      allowed = definition.options.map { |o| o.is_a?(Hash) ? o["key"] : o.to_s }
      errors << "Must be one of: #{allowed.join(', ')}" unless allowed.include?(value.to_s)
    when "multi_choice"
      allowed = definition.options.map { |o| o.is_a?(Hash) ? o["key"] : o.to_s }
      values = Array(value).map(&:to_s)
      invalid = values - allowed
      errors << "Invalid choices: #{invalid.join(', ')}" if invalid.any?
    when "date"
      begin
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        errors << "Must be a valid date"
      end
    end

    errors
  end
end

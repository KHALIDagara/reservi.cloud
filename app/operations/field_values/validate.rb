module FieldValues
  module Validate
    module_function

    def call(values:, definitions:)
      FieldValueValidator.validate_values(values, definitions)
    end
  end
end
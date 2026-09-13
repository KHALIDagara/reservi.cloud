# Development seed data: one Account with an admin user.
# Run with: bin/rails db:seed
# This is idempotent — safe to run multiple times.

unless Rails.env.production?
  email = ENV.fetch("RESERVI_SEED_EMAIL", "admin@reservi.dev")
  password = ENV.fetch("RESERVI_SEED_PASSWORD", "password123")
  account_name = ENV.fetch("RESERVI_SEED_ACCOUNT_NAME", "Reservi Dev")

  user = User.find_or_create_by!(email_address: email) do |u|
    u.name = "Dev Admin"
    u.password = password
    u.password_confirmation = password
    u.verified_at = Time.current
  end

  account = Accounts::Create.call(
    user: user,
    name: account_name,
    operation_key: "reservi-dev-seed-#{account_name.parameterize}",
    locale: "en",
    timezone: "UTC"
  )

  # Seed default field definitions
  unless account.field_definitions.exists?
    account.field_definitions.create!([
      { scope: "customer", key: "city", label: "City", field_type: "text", position: 1 },
      { scope: "customer", key: "phone", label: "Phone", field_type: "text", built_in_binding: "phone", position: 2 },
      { scope: "conversation", key: "budget", label: "Budget", field_type: "number", position: 1, constraints: { "min" => 0 } },
      { scope: "conversation", key: "urgency", label: "Urgency", field_type: "single_choice", position: 2, options: [{ "key" => "low", "label" => "Low" }, { "key" => "medium", "label" => "Medium" }, { "key" => "high", "label" => "High" }] },
    ])
  end

  # Create default Flow with one published Stage (literal=false completion —
  # never completes on its own; T04 adds the full interpreter).
  unless account.flows.exists?
    flow = account.flows.create!(name: "Default")
    version = flow.versions.create!(version_number: 1, status: "published", published_at: Time.current)
    stage = version.stages.create!(
      key: "stage_1",
      label: "Intake",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    flow.update!(current_version: version)
  end

  puts "Seed complete: Account '#{account_name}', user '#{email}'"
end

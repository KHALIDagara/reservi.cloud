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

  Accounts::Create.call(
    user: user,
    name: account_name,
    operation_key: "reservi-dev-seed-#{account_name.parameterize}",
    locale: "en",
    timezone: "UTC"
  )

  puts "Seed complete: Account '#{account_name}', user '#{email}'"
end

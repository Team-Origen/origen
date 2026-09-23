import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
runtime_database_url = System.get_env("ORIGEN_DATABASE_URL")

runtime_database_options =
  if runtime_database_url do
    [url: runtime_database_url]
  else
    [
      username:
        System.get_env(
          "ORIGEN_TEST_DB_USERNAME",
          System.get_env("PGUSER", System.get_env("USER"))
        ),
      password: System.get_env("ORIGEN_TEST_DB_PASSWORD", System.get_env("PGPASSWORD")),
      hostname: "localhost",
      port:
        String.to_integer(System.get_env("ORIGEN_TEST_DB_PORT", System.get_env("PGPORT", "5433"))),
      database: "origen_test#{System.get_env("MIX_TEST_PARTITION")}"
    ]
  end

config :origen,
       Origen.Repo,
       runtime_database_options ++
         [
           pool: Ecto.Adapters.SQL.Sandbox,
           pool_size: System.schedulers_online() * 2
         ]

config :origen,
  bootstrap_admin_enabled: false,
  consultation_catalog_demo_enabled: true,
  consultation_type_catalog_adapter: Origen.ConsultationTypes.MockCatalog,
  appointments_calendar_adapter: Origen.Appointments.MockCalendar,
  totp_keyring: %{
    active: %{tag: "test.v1", key: String.duplicate("k", 32)},
    retired: []
  },
  bootstrap_admin_delivery: %{
    enabled: false,
    allowed_adapters: [Origen.TestSupport.BootstrapAdmin.NonRetainingAdapter]
  }

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :origen, OrigenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JjPpHYhU6aY2HH3s9Q5oZ0xwmB6Re0U+7wIfHaMC0odTPEMyKgUoOXECPvrK3mKR",
  server: false

# In test we don't send emails
config :origen, Origen.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

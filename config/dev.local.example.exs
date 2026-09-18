import Config

# Copy this file to config/dev.local.exs and replace placeholders with local-only
# references. Never commit config/dev.local.exs, credentials, or key contents.
config :origen, Origen.Repo,
  username: "YOUR_DB_USERNAME",
  password: "YOUR_DB_PASSWORD",
  hostname: "localhost",
  port: 5433,
  database: "YOUR_ISOLATED_DEV_DATABASE"

# Keep disabled while preparing local files. Deliberately change both values to
# exact true only for the source-checkout local bootstrap exercise.
config :origen,
  bootstrap_admin_profile: :local,
  bootstrap_admin_local_enabled: false,
  bootstrap_admin_local: %{
    enabled: false,
    profile: :local,
    channel: :source_checkout,
    destination: "STUDENT@example.test",
    activation_origin: "https://127.0.0.1:PORT/admin/activate",
    endpoint: %{scheme: :https, ip: {127, 0, 0, 1}, port: "PORT", http: false},
    mailer: Origen.Mailer,
    adapter: Swoosh.Adapters.Local,
    storage: Swoosh.Adapters.Local.Storage.Memory,
    preview: Plug.Swoosh.MailboxPreview,
    retention_owner: Origen.BootstrapAdmin.Local.Mailbox,
    retention_ttl_seconds: "SECONDS_FROM_1_TO_900",
    max_messages: 1,
    certificate_file: "PATH_TO_LOCAL_CERTIFICATE",
    certificate_key_file: "PATH_TO_LOCAL_CERTIFICATE_KEY",
    verifier_key_file: "PATH_TO_VERIFIER_KEY_FILE",
    totp_key_file: "PATH_TO_TOTP_KEY_FILE",
    totp_key_tag: "local.dev.v1",
    database_name: "YOUR_ISOLATED_DEV_DATABASE",
    database_scope: :isolated_workstation
  }

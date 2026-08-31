import Config

# Copy this file to config/dev.local.exs and set local-only values.
# Never commit config/dev.local.exs or real credentials.
config :origen, Origen.Repo,
  username: "YOUR_DB_USERNAME",
  password: "YOUR_DB_PASSWORD",
  hostname: "localhost",
  port: 5433,
  database: "origen_dev"

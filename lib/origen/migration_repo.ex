defmodule Origen.MigrationRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :origen,
    adapter: Ecto.Adapters.Postgres

  @role_pattern ~r/^[a-z_][a-z0-9_]*$/

  def set_owner_role(connection) do
    role = System.fetch_env!("ORIGEN_OWNER_ROLE")

    unless Regex.match?(@role_pattern, role) do
      raise "ORIGEN_OWNER_ROLE must be a PostgreSQL identifier"
    end

    Postgrex.query!(connection, ~s(SET ROLE "#{role}"), [])
  end
end

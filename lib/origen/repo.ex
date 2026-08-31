defmodule Origen.Repo do
  use Ecto.Repo,
    otp_app: :origen,
    adapter: Ecto.Adapters.Postgres
end

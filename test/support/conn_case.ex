defmodule OrigenWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use OrigenWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint OrigenWeb.Endpoint

      use OrigenWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import OrigenWeb.ConnCase
    end
  end

  setup tags do
    unless tags[:skip_db] do
      Origen.DataCase.setup_sandbox(tags)
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Creates and stores an internal session for an active account.
  """
  def log_in_internal_account(conn, account) do
    {:ok, %{token: token}} = Origen.Sessions.create_session(account)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:internal_session_token, token)
  end

  @doc """
  Inserts an active internal account with the given role.
  """
  def insert_active_internal_account!(role) when is_atom(role) do
    %{rows: [[account_id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: account_id, role: role, state: :active}
  end
end

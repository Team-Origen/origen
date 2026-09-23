defmodule Origen.AvailabilityTest do
  use Origen.DataCase, async: false

  alias Origen.{Availability, Repo, Sessions}

  describe "get_own_configuration/1" do
    test "returns configured defaults through a revalidated Professional session" do
      principal = professional_principal!()

      assert {:ok, configuration} = Availability.get_own_configuration(principal)
      assert configuration.booking_horizon_days == 30
      assert configuration.minimum_lead_minutes == 30
      assert configuration.timezone == "Etc/UTC"
      assert configuration.agenda_interval_minutes == 30
      assert length(configuration.weekly_availability.monday) == 2
      assert configuration.weekly_availability.saturday == []
    end

    test "denies altered bindings, revoked sessions, inactive accounts, and other roles" do
      principal = professional_principal!()
      other = professional_principal!()

      assert {:error, :unauthorized} =
               Availability.get_own_configuration(%{principal | account_id: other.account_id})

      :ok = Sessions.terminate_all_sessions(principal.account_id)
      assert {:error, :unauthorized} = Availability.get_own_configuration(principal)

      administrator = :administrator |> insert_active_account!() |> principal_for!()
      assert {:error, :unauthorized} = Availability.get_own_configuration(administrator)

      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL,
            activated_at = NULL
        WHERE id = $1
        """,
        [other.account_id]
      )

      assert {:error, :unauthorized} = Availability.get_own_configuration(other)
    end

    test "denies and persistently revokes future-dated or expired sessions" do
      timestamp_mutations = [
        "issued_at = clock_timestamp() + interval '5 minutes'",
        "last_activity_at = clock_timestamp() + interval '5 minutes'",
        "issued_at = clock_timestamp() - interval '13 hours'",
        "last_activity_at = clock_timestamp() - interval '20 minutes'"
      ]

      for timestamp_mutation <- timestamp_mutations do
        principal = professional_principal!()

        Repo.query!(
          """
          UPDATE internal_account_sessions
          SET #{timestamp_mutation}
          WHERE id = $1
          """,
          [principal.session_id]
        )

        assert {:error, :unauthorized} = Availability.get_own_configuration(principal)
        refute is_nil(session_revoked_at(principal.session_id))
      end
    end
  end

  defp professional_principal!, do: :professional |> insert_active_account!() |> principal_for!()

  defp principal_for!(account_id) do
    {:ok, %{session: principal}} = Sessions.create_session(account_id)
    principal
  end

  defp insert_active_account!(role) do
    Repo.query!(
      """
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ($1, 'active', 'hash', decode('0102', 'hex'), NOW()) RETURNING id
      """,
      [Atom.to_string(role)]
    ).rows
    |> hd()
    |> hd()
  end

  defp session_revoked_at(session_id) do
    Repo.query!("SELECT revoked_at FROM internal_account_sessions WHERE id = $1", [session_id]).rows
    |> hd()
    |> hd()
  end
end

defmodule Origen.AvailabilityTest do
  use Origen.DataCase, async: false

  alias Origen.{Availability, Repo, Sessions}

  @empty_week Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []})

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

  describe "replace_own_configuration/2" do
    test "replaces the complete configuration, merges touching windows, and accepts empty weeks" do
      principal = professional_principal!()

      week =
        Map.put(@empty_week, "monday", [
          %{"start" => "09:00", "end" => "10:00"},
          %{"start" => "08:00", "end" => "09:00"}
        ])

      attrs = valid_attrs(week)

      assert {:ok, configuration} = Availability.replace_own_configuration(principal, attrs)
      assert configuration.weekly_availability.monday == [%{start: "08:00", end: "10:00"}]
      assert configuration.booking_horizon_days == 90
      assert configuration.minimum_lead_minutes == 0
      assert {:ok, ^configuration} = Availability.get_own_configuration(principal)

      assert {:ok, empty} =
               Availability.replace_own_configuration(principal, valid_attrs(@empty_week))

      assert Enum.all?(empty.weekly_availability, fn {_day, windows} -> windows == [] end)
    end

    test "accumulates actionable errors and preserves the previous configuration without success audit" do
      principal = professional_principal!()
      assert {:ok, before} = Availability.get_own_configuration(principal)
      audit_count = audit_count(principal.account_id)

      invalid = %{
        weekly_availability:
          Map.put(@empty_week, "monday", [
            %{"start" => "08:10", "end" => "09:00"},
            %{"start" => "08:30", "end" => "10:00"}
          ]),
        booking_horizon_days: 6,
        minimum_lead_minutes: 31
      }

      assert {:error, {:validation, errors}} =
               Availability.replace_own_configuration(principal, invalid)

      assert errors.booking_horizon_days == :out_of_range
      assert errors.minimum_lead_minutes == :invalid_increment
      assert errors.weekly_availability.monday in [:misaligned, :overlap]
      assert {:ok, ^before} = Availability.get_own_configuration(principal)
      assert audit_count(principal.account_id) == audit_count
    end

    test "rejects malformed, overnight, short, overlapping, and owner-supplied data" do
      principal = professional_principal!()

      invalid_weeks = [
        Map.put(@empty_week, "monday", [%{"start" => "18:00", "end" => "08:00"}]),
        Map.put(@empty_week, "monday", [%{"start" => "08:00", "end" => "08:15"}]),
        Map.put(@empty_week, "monday", [
          %{"start" => "08:00", "end" => "10:00"},
          %{"start" => "09:00", "end" => "11:00"}
        ]),
        Map.delete(@empty_week, "sunday")
      ]

      for week <- invalid_weeks do
        assert {:error, {:validation, %{weekly_availability: _reason}}} =
                 Availability.replace_own_configuration(principal, valid_attrs(week))
      end

      assert {:error, {:validation, %{base: :protected_fields}}} =
               Availability.replace_own_configuration(
                 principal,
                 Map.put(valid_attrs(), :owner_account_id, 42)
               )
    end

    test "commits one minimized audit event with the replacement" do
      principal = professional_principal!()

      assert {:ok, _configuration} =
               Availability.replace_own_configuration(principal, valid_attrs())

      assert [
               [
                 "professional",
                 actor_ref,
                 "availability_configuration_replaced",
                 "account",
                 entity_ref,
                 "succeeded"
               ]
             ] =
               Repo.query!(
                 """
                 SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result
                 FROM audit_events
                 WHERE event = 'availability_configuration_replaced' AND actor_ref = $1
                 """,
                 [Integer.to_string(principal.account_id)]
               ).rows

      assert actor_ref == entity_ref
    end

    test "rolls back configuration when the required audit append fails" do
      principal = professional_principal!()
      assert {:ok, before} = Availability.get_own_configuration(principal)
      install_audit_rejection_trigger!()

      assert {:error, :unavailable} =
               Availability.replace_own_configuration(principal, valid_attrs(@empty_week))

      assert {:ok, ^before} = Availability.get_own_configuration(principal)
    end
  end

  defp valid_attrs(week \\ @empty_week) do
    %{weekly_availability: week, booking_horizon_days: 90, minimum_lead_minutes: 0}
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

  defp audit_count(account_id) do
    Repo.query!(
      "SELECT count(*) FROM audit_events WHERE event = 'availability_configuration_replaced' AND actor_ref = $1",
      [Integer.to_string(account_id)]
    ).rows
    |> hd()
    |> hd()
  end

  defp session_revoked_at(session_id) do
    Repo.query!("SELECT revoked_at FROM internal_account_sessions WHERE id = $1", [session_id]).rows
    |> hd()
    |> hd()
  end

  defp install_audit_rejection_trigger! do
    Repo.query!("""
    CREATE FUNCTION pg_temp.reject_availability_audit() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.event = 'availability_configuration_replaced' THEN
        RAISE EXCEPTION 'test audit rejection';
      END IF;
      RETURN NEW;
    END $$
    """)

    Repo.query!("""
    CREATE TRIGGER test_reject_availability_audit BEFORE INSERT ON audit_events
    FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_availability_audit()
    """)
  end
end

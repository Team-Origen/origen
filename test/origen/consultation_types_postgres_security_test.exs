defmodule Origen.ConsultationTypesPostgresSecurityTest do
  use Origen.PostgresSecurityCase

  @moduletag :postgres_security

  setup_all context do
    roles = %{
      owner: System.get_env("ORIGEN_OWNER_ROLE", "origen_owner"),
      runtime: System.get_env("ORIGEN_RUNTIME_ROLE", "origen_runtime")
    }

    query!(context.migrator, ~s(SET ROLE "#{roles.owner}"))

    {:ok, Map.put(context, :roles, roles)}
  end

  setup %{migrator: owner} do
    account_id = insert_professional!(owner)

    on_exit(fn ->
      query!(owner, "DELETE FROM consultation_types WHERE owner_account_id = $1", [account_id])
      query!(owner, "DELETE FROM agenda_settings WHERE owner_account_id = $1", [account_id])
      query!(owner, "DELETE FROM internal_accounts WHERE id = $1", [account_id])
    end)

    {:ok, owner: owner, account_id: account_id}
  end

  test "runtime has exactly the business-table capabilities required by the context", context do
    %{runtime: runtime, owner: owner, account_id: account_id, roles: roles} = context
    consultation_type_id = Ecto.UUID.generate()

    for table <- ~w(agenda_settings consultation_types) do
      for privilege <- ~w(SELECT INSERT UPDATE) do
        assert scalar!(owner, "SELECT has_table_privilege($1, $2, $3)", [
                 roles.runtime,
                 table,
                 privilege
               ])
      end

      for privilege <- ~w(DELETE TRUNCATE REFERENCES TRIGGER) do
        refute scalar!(owner, "SELECT has_table_privilege($1, $2, $3)", [
                 roles.runtime,
                 table,
                 privilege
               ])
      end
    end

    assert scalar!(
             owner,
             "SELECT has_sequence_privilege($1, 'agenda_settings_id_seq', 'USAGE')",
             [roles.runtime]
           )

    assert %{rows: [[_settings_id]]} =
             query!(runtime, """
             INSERT INTO agenda_settings (owner_account_id, interval_minutes)
             VALUES (#{account_id}, 30)
             RETURNING id
             """)

    assert %{num_rows: 1} =
             query!(runtime, """
             INSERT INTO consultation_types
               (id, owner_account_id, name, exact_price_ars, color, interval_count,
                status, inactive_duration_minutes)
             VALUES
               ('#{consultation_type_id}', #{account_id}, 'Runtime consultation', 18000.00,
                '#0A7C86', 2, 'active', NULL)
             """)

    assert %{num_rows: 1} =
             query!(runtime, """
             UPDATE agenda_settings SET interval_minutes = 20
             WHERE owner_account_id = #{account_id}
             """)

    assert %{num_rows: 1} =
             query!(runtime, """
             UPDATE consultation_types SET name = 'Updated by runtime', interval_count = 3
             WHERE id = '#{consultation_type_id}'
             """)

    assert query!(runtime, """
           SELECT settings.interval_minutes, types.name, types.interval_count
           FROM agenda_settings AS settings
           JOIN consultation_types AS types
             ON types.owner_account_id = settings.owner_account_id
           WHERE settings.owner_account_id = #{account_id}
           """).rows == [[20, "Updated by runtime", 3]]
  end

  test "runtime cannot change ownership, destroy data, perform DDL, or mutate audit history",
       context do
    %{runtime: runtime, owner: owner, account_id: account_id} = context
    other_account_id = insert_professional!(owner)
    consultation_type_id = Ecto.UUID.generate()
    replacement_id = Ecto.UUID.generate()

    on_exit(fn ->
      query!(owner, "DELETE FROM internal_accounts WHERE id = $1", [other_account_id])
    end)

    query!(owner, """
    INSERT INTO agenda_settings (owner_account_id, interval_minutes)
    VALUES (#{account_id}, 30)
    """)

    query!(owner, """
    INSERT INTO consultation_types
      (id, owner_account_id, name, exact_price_ars, color, interval_count,
       status, inactive_duration_minutes)
    VALUES
      ('#{consultation_type_id}', #{account_id}, 'Protected consultation', 18000.00,
       '#0A7C86', 2, 'active', NULL)
    """)

    query!(runtime, """
    INSERT INTO audit_events
      (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
    VALUES
      ('system', NULL, 'consultation_security_probe', 'consultation_type',
       '#{consultation_type_id}', 'succeeded')
    """)

    audit_history = query!(owner, "SELECT * FROM audit_events ORDER BY id").rows

    immutable_updates = [
      {:generated_always,
       "UPDATE agenda_settings SET id = id + 1 WHERE owner_account_id = #{account_id}"},
      {:integrity_constraint_violation,
       "UPDATE agenda_settings SET owner_account_id = #{other_account_id} WHERE owner_account_id = #{account_id}"},
      {:integrity_constraint_violation,
       "UPDATE consultation_types SET id = '#{replacement_id}' WHERE id = '#{consultation_type_id}'"},
      {:integrity_constraint_violation,
       "UPDATE consultation_types SET owner_account_id = #{other_account_id} WHERE id = '#{consultation_type_id}'"}
    ]

    for {expected_sqlstate, sql} <- immutable_updates do
      assert_sqlstate(runtime, sql, expected_sqlstate)
    end

    for sql <- [
          "DELETE FROM consultation_types WHERE id = '#{consultation_type_id}'",
          "DELETE FROM agenda_settings WHERE owner_account_id = #{account_id}",
          "TRUNCATE consultation_types",
          "TRUNCATE agenda_settings",
          "ALTER TABLE consultation_types ADD COLUMN forbidden text",
          "DROP TABLE agenda_settings",
          "CREATE TABLE public.runtime_consultation_probe (id integer)",
          "UPDATE audit_events SET result = 'failed'",
          "TRUNCATE audit_events"
        ] do
      assert_sqlstate(runtime, sql, :insufficient_privilege)
    end

    assert query!(owner, """
           SELECT owner_account_id, interval_minutes FROM agenda_settings
           WHERE owner_account_id = #{account_id}
           """).rows == [[account_id, 30]]

    assert query!(owner, """
           SELECT id::text, owner_account_id, name FROM consultation_types
           WHERE id = '#{consultation_type_id}'
           """).rows == [[consultation_type_id, account_id, "Protected consultation"]]

    assert query!(owner, "SELECT * FROM audit_events ORDER BY id").rows == audit_history
  end

  defp insert_professional!(owner) do
    scalar!(owner, """
    INSERT INTO internal_accounts
      (role, state, password_hash, totp_secret, activated_at)
    VALUES
      ('professional', 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
    RETURNING id
    """)
  end
end

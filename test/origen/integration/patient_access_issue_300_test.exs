defmodule Origen.Integration.PatientAccessIssue300Test do
  @moduledoc """
  Real, test-database integration journey for Issue #300.

  The test uses `OrigenWeb.ConnCase`, whose SQL sandbox rolls back every change at
  the end of the test. Magic Link tokens are captured from the local Swoosh
  delivery rather than inserted or fabricated by the test.
  """

  use OrigenWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Origen.PatientAccess
  alias Origen.PatientAccess.MagicLink
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Booking.Appointment
  alias Origen.Repo

  test "completes the assisted patient access journey with replacement and isolation" do
    audit_floor = Repo.one(from a in "audit_events", select: max(a.id)) || 0
    suffix = System.unique_integer([:positive])

    secretary = insert_internal_account!("secretary", suffix)
    professional = insert_internal_account!("professional", suffix)
    administrator = insert_internal_account!("administrator", suffix)

    old_email = "patient-#{suffix}@example.test"
    new_email = "patient-renewed-#{suffix}@example.test"
    contact_email = "family-contact-#{suffix}@example.test"
    other_email = "other-patient-#{suffix}@example.test"

    assisted_attrs = %{
      first_name: "María",
      last_name: "López",
      document_type: "dni",
      document_number: "30.111.222",
      birthdate: ~D[1989-04-12],
      phone: "+5491112345678",
      email: contact_email
    }

    assert {:ok, %{persona: persona, profile: profile, outcome: :created}} =
             Patients.register_absent_patient(assisted_attrs, secretary.id)

    assert profile.email == nil
    assert profile.contact_email == contact_email
    assert profile.state == "completed"

    {:ok, %{profile: other_profile}} =
      Patients.register_absent_patient(
        %{
          first_name: "Julián",
          last_name: "Gómez",
          document_type: "dni",
          document_number: "30.111.223",
          birthdate: ~D[1990-06-21],
          phone: "+5491198765432",
          email: other_email
        },
        secretary.id
      )

    consultation_type_id = insert_consultation_type!(professional.id, suffix)

    historical_appointment =
      insert_historical_appointment!(
        profile.id,
        professional.id,
        consultation_type_id
      )

    # The authorized staff domain operation links access and emits a real local email.
    assert {:ok, %{patient_profile: linked, outcome: :linked}} =
             Patients.link_patient_access_email(profile.id, old_email, secretary.id)

    assert linked.email == old_email
    assert linked.contact_email == contact_email
    old_token = receive_magic_token!(old_email)

    old_link =
      Repo.one!(from m in MagicLink, where: m.email == ^old_email and is_nil(m.consumed_at))

    assert old_link.token_digest == :crypto.hash(:sha256, old_token)
    refute old_link.token_digest == old_token

    # Consume the actual local link through the public HTTP endpoint.
    old_conn = get(build_conn(), ~p"/access/verify?token=#{old_token}")
    assert redirected_to(old_conn) == ~p"/"
    assert get_session(old_conn, :patient_email) == old_email
    old_authenticated_at = get_session(old_conn, :patient_authenticated_at)
    assert {:ok, _old_auth_dt, _offset} = DateTime.from_iso8601(old_authenticated_at)

    # A patient session can reach the patient-facing LiveView, but only renders
    # the identity belonging to that session.
    {:ok, _old_view, old_html} = live(old_conn, ~p"/patient/calendar")
    assert old_html =~ "María López"
    refute old_html =~ "Julián Gómez"

    # Keep a second, still-pending old-email token so replacement proves pending
    # token invalidation independently from the consumed login token.
    assert {:ok, :delivered} = PatientAccess.request_magic_link(old_email)
    pending_old_token = receive_magic_token!(old_email)

    # A professional is also authorized to perform the replacement operation.
    reason = "Actualización solicitada en consultorio"

    assert {:ok, %{patient_profile: replaced, outcome: :replaced}} =
             Patients.replace_patient_access_email(
               profile.id,
               new_email,
               professional.id,
               reason
             )

    assert replaced.email == new_email
    assert replaced.contact_email == contact_email
    assert replaced.persona_id == persona.id
    assert replaced.sessions_invalidated_at != nil

    reloaded_profile = Repo.get!(PatientProfile, profile.id)
    reloaded_persona = Repo.get!(Persona, persona.id)
    reloaded_appointment = Repo.get!(Appointment, historical_appointment.id)

    # Identity, contact email, and historical appointment remain attached to the
    # same patient after changing only the personal access credential.
    assert reloaded_profile.email == new_email
    assert reloaded_profile.contact_email == contact_email
    assert reloaded_profile.persona_id == persona.id
    assert reloaded_persona.first_name == "María"
    assert reloaded_persona.last_name == "López"
    assert reloaded_persona.document_type == "dni"
    assert reloaded_persona.document_number == "30111222"
    assert reloaded_persona.birthdate == ~D[1989-04-12]
    assert reloaded_appointment.patient_profile_id == profile.id
    assert reloaded_appointment.professional_account_id == professional.id
    assert reloaded_appointment.status == "confirmed"
    assert reloaded_appointment.snapshot_consultation_type_name == "Consulta histórica"
    assert reloaded_appointment.snapshot_duration_minutes == 30
    assert Decimal.equal?(reloaded_appointment.snapshot_exact_price_ars, Decimal.new("12500.00"))

    # The pending old token is invalidated by replacement, and the session
    # timestamp issued before replacement is rejected as stale.
    assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link(pending_old_token)

    assert {:error, :session_invalidated} =
             Patients.verify_patient_session(new_email, old_authenticated_at)

    assert {:error, {:redirect, %{to: "/access"}}} =
             live(old_conn, ~p"/patient/calendar")

    # Replacement dispatches a new real local Magic Link, which creates a fresh
    # session through the same public endpoint.
    new_token = receive_magic_token!(new_email)
    new_conn = get(build_conn(), ~p"/access/verify?token=#{new_token}")
    assert redirected_to(new_conn) == ~p"/"
    assert get_session(new_conn, :patient_email) == new_email
    new_authenticated_at = get_session(new_conn, :patient_authenticated_at)
    assert {:ok, _new_auth_dt, _offset} = DateTime.from_iso8601(new_authenticated_at)

    assert {:ok, _verified_profile} =
             Patients.verify_patient_session(new_email, new_authenticated_at)

    {:ok, _new_view, new_html} = live(new_conn, ~p"/patient/calendar")
    assert new_html =~ "María López"
    refute new_html =~ "Julián Gómez"

    # An administrator cannot use either staff-only domain operation, and a
    # denied operation does not change the persisted profile.
    assert {:error, :unauthorized} =
             Patients.link_patient_access_email(
               profile.id,
               "admin-link-#{suffix}@example.test",
               administrator.id
             )

    assert {:error, :unauthorized} =
             Patients.replace_patient_access_email(
               profile.id,
               "admin-replace-#{suffix}@example.test",
               administrator.id,
               "Intento no autorizado"
             )

    assert Repo.get!(PatientProfile, profile.id).email == new_email
    refute_receive {:email, _email}, 100

    # The public /access response is opaque for an unknown email and does not
    # create a Magic Link or deliver a message.
    unknown_email = "unknown-#{suffix}@example.test"
    before_unknown_links = Repo.aggregate(MagicLink, :count)

    {:ok, access_view, _access_html} = live(build_conn(), ~p"/access")

    unknown_html =
      access_view
      |> form("#patient-access-form", access: %{email: unknown_email})
      |> render_submit()

    assert unknown_html =~ "Revisá tu casilla de correo"
    assert unknown_html =~ "Si el correo ingresado corresponde a un paciente registrado"
    refute unknown_html =~ unknown_email
    assert Repo.aggregate(MagicLink, :count) == before_unknown_links
    refute_receive {:email, _email}, 100

    # Audit rows are present for the journey, but contain no raw token, URL, or
    # replacement reason. The operation references remain bounded and typed.
    audit_rows =
      Repo.all(
        from a in "audit_events",
          where: a.id > ^audit_floor,
          select: %{
            actor_kind: a.actor_kind,
            actor_ref: a.actor_ref,
            event: a.event,
            entity_kind: a.entity_kind,
            entity_ref: a.entity_ref,
            result: a.result,
            recorded_at: a.recorded_at
          }
      )

    assert Enum.any?(audit_rows, &(&1.event == "patient_access_email_linked"))
    assert Enum.any?(audit_rows, &(&1.event == "patient_access_email_replaced"))
    assert Enum.any?(audit_rows, &(&1.event == "magic_link_issued"))

    assert Enum.any?(
             audit_rows,
             &(&1.event == "magic_link_consumed" and &1.result == "succeeded")
           )

    sensitive_values = [old_token, pending_old_token, new_token, reason, "/access/verify?token="]

    for row <- audit_rows do
      serialized = inspect(row)
      assert row.recorded_at != nil
      refute Enum.any?(sensitive_values, &String.contains?(serialized, &1))
      refute serialized =~ ~r/https?:\/\//i
      assert row.actor_ref == nil or row.actor_kind == "patient" or row.actor_ref =~ ~r/^\d+$/
      assert row.entity_kind in [nil, "account", "patient"]
    end

    # The second identity was created only to exercise ownership isolation and
    # remains unrelated to the authenticated patient's profile.
    assert Repo.get!(PatientProfile, other_profile.id).email == nil
  end

  defp receive_magic_token!(recipient) do
    receive do
      {:email, email} ->
        assert email.to == [{"", recipient}]
        [_, encoded_token] = Regex.run(~r{/access/verify\?token=([^"&]+)}, email.html_body)
        URI.decode_www_form(encoded_token)
    after
      1_000 -> flunk("Expected a local Magic Link email for #{recipient}")
    end
  end

  defp insert_internal_account!(role, suffix) do
    %{rows: [[account_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (email, role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, $2, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        ["issue-300-#{role}-#{suffix}@example.test", role]
      )

    %{id: account_id, role: String.to_atom(role)}
  end

  defp insert_consultation_type!(professional_id, suffix) do
    consultation_type_id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, 12500.00, '#0A3847', 1, 'active')
      """,
      [
        Ecto.UUID.dump!(consultation_type_id),
        professional_id,
        "Consulta histórica #{suffix}"
      ]
    )

    consultation_type_id
  end

  defp insert_historical_appointment!(profile_id, professional_id, consultation_type_id) do
    attrs = %{
      patient_profile_id: profile_id,
      professional_account_id: professional_id,
      consultation_type_id: consultation_type_id,
      start_time: ~U[2020-01-15 10:00:00Z],
      end_time: ~U[2020-01-15 10:30:00Z],
      status: "confirmed",
      snapshot_consultation_type_name: "Consulta histórica",
      snapshot_duration_minutes: 30,
      snapshot_exact_price_ars: Decimal.new("12500.00")
    }

    %Appointment{}
    |> Appointment.changeset(attrs)
    |> Repo.insert!()
  end
end

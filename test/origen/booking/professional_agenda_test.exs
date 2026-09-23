defmodule Origen.Booking.ProfessionalAgendaTest do
  @moduledoc """
  Suite de la consulta de agenda propia del Profesional (Issue #79 / PLN-10).

  Verifica que la identidad se derive exclusivamente de la sesión autenticada
  revalidada en el servidor, el aislamiento estricto entre agendas de distintos
  profesionales, la inmunidad ante intentos de ampliación de alcance mediante
  parámetros del cliente y la proyección no clínica de Paciente.
  """

  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @target_date ~D[2026-10-15]
  @target_date_iso "2026-10-15"

  setup do
    professional_a = professional_principal!()
    professional_b = professional_principal!()

    consultation_type_id = insert_consultation_type!(professional_a.account_id)

    %{
      professional_a: professional_a,
      professional_b: professional_b,
      consultation_type_id: consultation_type_id,
      patient_with_persona: insert_patient!(persona?: true, email: "juan.perez@example.com"),
      patient_without_persona: insert_patient!(persona?: false, email: "solo.email@example.com")
    }
  end

  describe "get_professional_agenda/2 con sesión válida" do
    test "retorna solo los turnos propios del día objetivo en orden cronológico", ctx do
      early =
        insert_appointment!(ctx, ctx.patient_without_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 00:00:00Z]
        )

      late =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 23:30:00Z]
        )

      first =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 09:00:00Z],
          status: "confirmed"
        )

      second =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 10:30:00Z],
          status: "reserved"
        )

      # Turno ajeno en el mismo rango horario: nunca debe aparecer.
      b_own =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_b.account_id,
          start_time: ~U[2026-10-15 09:30:00Z]
        )

      assert {:ok, agenda} =
               Booking.get_professional_agenda(ctx.professional_a, %{"date" => @target_date_iso})

      assert agenda.date == @target_date
      assert agenda.professional_account_id == ctx.professional_a.account_id
      assert Enum.map(agenda.appointments, & &1.id) == [early.id, first.id, second.id, late.id]
      assert b_own.id not in Enum.map(agenda.appointments, & &1.id)

      appointment = Enum.at(agenda.appointments, 1)
      assert appointment.start_time == ~U[2026-10-15 09:00:00.000000Z]
      assert appointment.end_time == ~U[2026-10-15 09:30:00.000000Z]
      assert appointment.status == "confirmed"
      assert appointment.consultation_type_name == "Consulta General"
      assert appointment.duration_minutes == 30
      assert Decimal.equal?(appointment.price_ars, Decimal.new("15000.50"))
    end

    test "proyecta datos de Paciente no clínicos con nombre resuelto de la persona o del email",
         ctx do
      insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
        start_time: ~U[2026-10-15 09:00:00Z]
      )

      insert_appointment!(ctx, ctx.patient_without_persona, ctx.professional_a.account_id,
        start_time: ~U[2026-10-15 10:00:00Z]
      )

      assert {:ok, agenda} =
               Booking.get_professional_agenda(ctx.professional_a, %{date: @target_date})

      [with_persona, without_persona] = agenda.appointments

      assert with_persona.patient == %{
               id: ctx.patient_with_persona,
               name: "Juan Perez",
               first_name: "Juan",
               last_name: "Perez",
               email: "juan.perez@example.com",
               phone: "+5491100001111",
               document_type: "dni",
               document_number: "30111222"
             }

      assert without_persona.patient == %{
               id: ctx.patient_without_persona,
               name: "solo.email@example.com",
               first_name: nil,
               last_name: nil,
               email: "solo.email@example.com",
               phone: "+5491100002222",
               document_type: nil,
               document_number: nil
             }
    end

    test "la proyección del turno y del Paciente no expone campos clínicos ni internos", ctx do
      insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
        start_time: ~U[2026-10-15 09:00:00Z]
      )

      assert {:ok, agenda} =
               Booking.get_professional_agenda(ctx.professional_a, %{"date" => @target_date_iso})

      [appointment] = agenda.appointments

      assert Enum.sort(Map.keys(appointment)) ==
               ~w(consultation_type_name duration_minutes end_time id patient price_ars start_time status)a

      assert Enum.sort(Map.keys(appointment.patient)) ==
               ~w(document_number document_type email first_name id last_name name phone)a
    end

    test "acepta Date, cadena ISO8601 y struct InternalSession", ctx do
      insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
        start_time: ~U[2026-10-15 09:00:00Z]
      )

      assert {:ok, %{appointments: [%{id: id}]}} =
               Booking.get_professional_agenda(ctx.professional_a, %{date: @target_date})

      assert {:ok, %{appointments: [%{id: ^id}]}} =
               Booking.get_professional_agenda(ctx.professional_a, %{"date" => @target_date_iso})

      assert {:ok, %{appointments: [%{id: ^id}]}} =
               Booking.get_professional_agenda(ctx.professional_a, %{date: @target_date_iso})

      session = %InternalSession{
        id: ctx.professional_a.session_id,
        account_id: ctx.professional_a.account_id
      }

      assert {:ok, %{appointments: [%{id: ^id}]}} =
               Booking.get_professional_agenda(session, %{date: @target_date})
    end

    test "por defecto consulta el día actual UTC", ctx do
      assert {:ok, agenda} = Booking.get_professional_agenda(ctx.professional_a, %{})

      assert agenda == %{
               date: Date.utc_today(),
               professional_account_id: ctx.professional_a.account_id,
               appointments: []
             }
    end

    test "el filtro de día es el intervalo semiabierto [inicio, fin) en UTC", ctx do
      previous_day =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-14 23:30:00Z]
        )

      at_midnight =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 00:00:00Z]
        )

      next_day =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-16 00:00:00Z]
        )

      assert {:ok, agenda} =
               Booking.get_professional_agenda(ctx.professional_a, %{"date" => @target_date_iso})

      ids = Enum.map(agenda.appointments, & &1.id)
      assert ids == [at_midnight.id]
      assert previous_day.id not in ids
      assert next_day.id not in ids
    end

    test "un día sin turnos retorna una agenda vacía", ctx do
      assert {:ok, agenda} =
               Booking.get_professional_agenda(ctx.professional_a, %{"date" => "2030-01-01"})

      assert agenda == %{
               date: ~D[2030-01-01],
               professional_account_id: ctx.professional_a.account_id,
               appointments: []
             }
    end
  end

  describe "aislamiento entre profesionales" do
    test "cada profesional ve únicamente sus propios turnos y nunca los del colega", ctx do
      a_own =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 09:00:00Z]
        )

      b_own =
        insert_appointment!(ctx, ctx.patient_without_persona, ctx.professional_b.account_id,
          start_time: ~U[2026-10-15 10:00:00Z]
        )

      assert {:ok, agenda_a} =
               Booking.get_professional_agenda(ctx.professional_a, %{"date" => @target_date_iso})

      assert {:ok, agenda_b} =
               Booking.get_professional_agenda(ctx.professional_b, %{"date" => @target_date_iso})

      assert Enum.map(agenda_a.appointments, & &1.id) == [a_own.id]
      assert agenda_a.professional_account_id == ctx.professional_a.account_id
      assert Enum.map(agenda_b.appointments, & &1.id) == [b_own.id]
      assert agenda_b.professional_account_id == ctx.professional_b.account_id
    end
  end

  describe "parámetros del cliente no amplían el alcance" do
    test "identificadores inyectados de otro profesional se ignoran por completo", ctx do
      own =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 09:00:00Z]
        )

      insert_appointment!(ctx, ctx.patient_without_persona, ctx.professional_b.account_id,
        start_time: ~U[2026-10-15 10:00:00Z]
      )

      for key <- [
            :professional_account_id,
            "professional_account_id",
            :professional_id,
            "professional_id",
            :account_id,
            "account_id",
            :owner_account_id,
            "owner_account_id"
          ] do
        params = %{"date" => @target_date_iso} |> Map.put(key, ctx.professional_b.account_id)

        assert {:ok, agenda} = Booking.get_professional_agenda(ctx.professional_a, params)

        assert agenda.professional_account_id == ctx.professional_a.account_id
        assert Enum.map(agenda.appointments, & &1.id) == [own.id]
      end
    end

    test "valores arbitrarios o mal tipados en campos de identidad no alteran la consulta", ctx do
      own =
        insert_appointment!(ctx, ctx.patient_with_persona, ctx.professional_a.account_id,
          start_time: ~U[2026-10-15 09:00:00Z]
        )

      for value <- [
            ctx.professional_b.account_id + 99,
            "todas-las-agendas",
            nil,
            %{injected: true}
          ] do
        params = %{
          "date" => @target_date_iso,
          "professional_account_id" => value,
          "account_id" => value,
          "professional_id" => value
        }

        assert {:ok, agenda} = Booking.get_professional_agenda(ctx.professional_a, params)
        assert Enum.map(agenda.appointments, & &1.id) == [own.id]
      end
    end
  end

  describe "fail closed ante sesiones inválidas o roles no autorizados" do
    test "rechaza vinculación alterada entre sesión y cuenta", ctx do
      params = %{"date" => @target_date_iso}

      assert {:error, :unauthorized} =
               Booking.get_professional_agenda(
                 %{ctx.professional_a | account_id: ctx.professional_b.account_id},
                 params
               )

      assert {:error, :unauthorized} =
               Booking.get_professional_agenda(
                 %{
                   session_id: ctx.professional_a.session_id + 99_999,
                   account_id: ctx.professional_a.account_id
                 },
                 params
               )
    end

    test "rechaza sesión revocada o expirada" do
      revoked = professional_principal!()

      Repo.query!(
        "UPDATE internal_account_sessions SET revoked_at = clock_timestamp() WHERE id = $1",
        [revoked.session_id]
      )

      assert {:error, :unauthorized} =
               Booking.get_professional_agenda(revoked, %{"date" => @target_date_iso})

      expired = professional_principal!()

      Repo.query!(
        "UPDATE internal_account_sessions SET issued_at = clock_timestamp() - interval '13 hours' WHERE id = $1",
        [expired.session_id]
      )

      assert {:error, :unauthorized} =
               Booking.get_professional_agenda(expired, %{"date" => @target_date_iso})
    end

    test "rechaza cuenta inactiva y roles distintos a profesional" do
      suspended = professional_principal!()

      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL, activated_at = NULL
        WHERE id = $1
        """,
        [suspended.account_id]
      )

      assert {:error, :unauthorized} =
               Booking.get_professional_agenda(suspended, %{"date" => @target_date_iso})

      for role <- [:administrator, :secretary] do
        other_role = role |> insert_active_account!() |> principal_for!()

        assert {:error, :unauthorized} =
                 Booking.get_professional_agenda(other_role, %{"date" => @target_date_iso})
      end
    end

    test "rechaza principals malformados", ctx do
      params = %{"date" => @target_date_iso}

      for principal <- [
            %{},
            %{session_id: ctx.professional_a.session_id},
            %{session_id: "x", account_id: ctx.professional_a.account_id},
            nil,
            42
          ] do
        assert {:error, :unauthorized} = Booking.get_professional_agenda(principal, params)
      end
    end
  end

  describe "validación de fecha" do
    test "retorna invalid_date ante cadenas o tipos ilegibles", ctx do
      for date <- [
            "no-una-fecha",
            "15/10/2026",
            "2026-2-30",
            "",
            "2026-10-15T09:00:00Z",
            15,
            {:date, "x"}
          ] do
        assert {:error, :invalid_date} =
                 Booking.get_professional_agenda(ctx.professional_a, %{"date" => date})
      end
    end
  end

  # Fixtures y helpers

  defp professional_principal!, do: :professional |> insert_active_account!() |> principal_for!()

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

  defp principal_for!(account_id) do
    {:ok, %{session: principal}} = Sessions.create_session(account_id)
    principal
  end

  defp insert_consultation_type!(owner_account_id) do
    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Consulta General', 15000.50, '#112233', 1, 'active')
      RETURNING id
      """,
      [Ecto.UUID.bingenerate(), owner_account_id]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_patient!(persona?: true, email: email) do
    persona_id =
      Repo.query!(
        """
        INSERT INTO personas (first_name, last_name, document_type, document_number, birthdate)
        VALUES ('Juan', 'Perez', 'dni', $1, '1990-01-01')
        RETURNING id
        """,
        ["30111222"]
      ).rows
      |> hd()
      |> hd()

    insert_patient_profile!(persona_id, email, "+5491100001111")
  end

  defp insert_patient!(persona?: false, email: email) do
    insert_patient_profile!(nil, email, "+5491100002222")
  end

  defp insert_patient_profile!(persona_id, email, phone) do
    Repo.query!(
      """
      INSERT INTO patient_profiles (persona_id, email, state, phone, phone_verified)
      VALUES ($1, $2, 'completed', $3, true)
      RETURNING id
      """,
      [persona_id, email, phone]
    ).rows
    |> hd()
    |> hd()
  end

  defp insert_appointment!(ctx, patient_profile_id, professional_account_id, opts) do
    start_time = Keyword.fetch!(opts, :start_time)
    status = Keyword.get(opts, :status, "reserved")
    end_time = DateTime.add(start_time, 30, :minute)

    Repo.query!(
      """
      INSERT INTO appointments
        (patient_profile_id, professional_account_id, consultation_type_id,
         start_time, end_time, status,
         snapshot_consultation_type_name, snapshot_duration_minutes, snapshot_exact_price_ars)
      VALUES ($1, $2, $3, $4, $5, $6, 'Consulta General', 30, 15000.50)
      RETURNING id
      """,
      [
        patient_profile_id,
        professional_account_id,
        ctx.consultation_type_id,
        start_time,
        end_time,
        status
      ]
    ).rows
    |> hd()
    |> hd()
    |> then(&%{id: &1})
  end
end

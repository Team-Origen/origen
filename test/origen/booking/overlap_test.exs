defmodule Origen.Booking.OverlapTest do
  @moduledoc """
  Pruebas de prevención de solapamientos de turnos (Issue #65 / PLN-08, ODD-08-13).

  Cubre las reglas de dominio de `Origen.Booking.Overlap`, su exposición vía
  `Origen.Booking`, la precondición en `persist_appointment/2` y las restricciones
  de exclusión PostgreSQL que garantizan la integridad ante concurrencia.
  """

  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Booking
  alias Origen.Booking.Overlap
  alias Origen.Repo

  @consultation_type_id "7d4e2a90-1b2c-4d3e-9f8a-6543210abc65"

  @snapshot %{
    name: "Consulta Overlap",
    duration_minutes: 30,
    exact_price_ars: Decimal.new("15000.00")
  }

  setup do
    :ok = Sandbox.checkout(Repo)
    fixture = insert_fixture!()
    %{fixture: fixture}
  end

  describe "Overlap.validate_no_overlap/1 (agenda del profesional)" do
    test "rechaza solapamiento parcial", ctx do
      {:ok, _} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:error, :professional_schedule_conflict} =
               Overlap.validate_no_overlap(check_params(ctx, ~U[2026-10-20 09:15:00Z], 30))
    end

    test "rechaza contención total del intervalo propuesto", ctx do
      {:ok, _} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 60)

      assert {:error, :professional_schedule_conflict} =
               Overlap.validate_no_overlap(check_params(ctx, ~U[2026-10-20 09:15:00Z], 30))
    end

    test "rechaza el slot idéntico", ctx do
      {:ok, _} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:error, :professional_schedule_conflict} =
               Overlap.validate_no_overlap(check_params(ctx, ~U[2026-10-20 09:00:00Z], 30))
    end

    test "permite turnos contiguos (semántica semiabierta [))", ctx do
      {:ok, _} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:ok, :no_conflict} =
               Overlap.validate_no_overlap(check_params(ctx, ~U[2026-10-20 09:30:00Z], 30))
    end

    test "los turnos cancelados liberan el bloque horario", ctx do
      {:ok, _} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          Repo,
          "UPDATE public.appointments SET status = 'cancelled', updated_at = clock_timestamp() WHERE professional_account_id = $1",
          [ctx.fixture.professional_id]
        )

      assert {:ok, :no_conflict} =
               Overlap.validate_no_overlap(check_params(ctx, ~U[2026-10-20 09:00:00Z], 30))
    end

    test "no interpone conflictos entre distintos profesionales y pacientes", ctx do
      {:ok, _} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:ok, :no_conflict} =
               Overlap.validate_no_overlap(%{
                 professional_account_id: ctx.fixture.other_professional_id,
                 patient_profile_id: ctx.fixture.patient_id,
                 start_time: ~U[2026-10-20 09:00:00Z],
                 end_time: ~U[2026-10-20 09:30:00Z]
               })
    end
  end

  describe "Overlap.validate_no_overlap/1 (agenda del paciente)" do
    test "rechaza paciente simultáneo incluso con otro profesional", ctx do
      {:ok, _} = persist!(ctx, patient: :main, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:error, :patient_schedule_conflict} =
               Overlap.validate_no_overlap(%{
                 professional_account_id: ctx.fixture.other_professional_id,
                 patient_profile_id: ctx.fixture.patient_id,
                 start_time: ~U[2026-10-20 09:15:00Z],
                 end_time: ~U[2026-10-20 09:45:00Z]
               })
    end

    test "acepta al mismo paciente en un horario sin solapamiento", ctx do
      {:ok, _} = persist!(ctx, patient: :main, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:ok, :no_conflict} =
               Overlap.validate_no_overlap(%{
                 professional_account_id: ctx.fixture.other_professional_id,
                 patient_profile_id: ctx.fixture.patient_id,
                 start_time: ~U[2026-10-20 09:30:00Z],
                 end_time: ~U[2026-10-20 10:00:00Z]
               })
    end
  end

  describe "Overlap.validate_no_overlap/1 (parámetros)" do
    test "retorna invalid_overlap_params ante atributos ausentes o inválidos", ctx do
      assert {:error, :invalid_overlap_params} = Overlap.validate_no_overlap(%{})
      assert {:error, :invalid_overlap_params} = Overlap.validate_no_overlap(nil)

      assert {:error, :invalid_overlap_params} =
               Overlap.validate_no_overlap(%{
                 "professional_account_id" => ctx.fixture.professional_id,
                 "patient_profile_id" => ctx.fixture.patient_id,
                 "start_time" => "2026-10-20 09:00:00Z",
                 "end_time" => ~U[2026-10-20 09:30:00Z]
               })
    end

    test "acepta claves string y los alias professional_id/patient_id", ctx do
      assert {:ok, :no_conflict} =
               Overlap.validate_no_overlap(%{
                 "professional_id" => ctx.fixture.professional_id,
                 "patient_id" => ctx.fixture.patient_id,
                 "start_time" => ~U[2026-10-20 09:00:00Z],
                 "end_time" => ~U[2026-10-20 09:30:00Z]
               })
    end
  end

  describe "exposición vía Origen.Booking" do
    test "Booking.validate_no_overlap delega en Origen.Booking.Overlap", ctx do
      assert {:ok, _} =
               persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:error, :professional_schedule_conflict} =
               Booking.validate_no_overlap(check_params(ctx, ~U[2026-10-20 09:00:00Z], 30))

      assert {:ok, :no_conflict} =
               Booking.check_overlaps(check_params(ctx, ~U[2026-10-20 09:30:00Z], 30))
    end
  end

  describe "Booking.persist_appointment/2 con precondición de solapamiento" do
    test "retorna slot_already_booked y preserva el turno existente", ctx do
      {:ok, existing} =
        persist!(ctx, patient: :other, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:error, :slot_already_booked} =
               Booking.persist_appointment(
                 appointment_attrs(ctx, ~U[2026-10-20 09:15:00Z]),
                 snapshot(45)
               )

      assert count_appointments(ctx.fixture.professional_id) == 1
      assert Repo.get!(Origen.Booking.Appointment, existing.id).status == "reserved"
    end

    test "retorna patient_schedule_conflict para paciente simultáneo con otro profesional", ctx do
      {:ok, _} =
        persist!(ctx, patient: :main, start_time: ~U[2026-10-20 09:00:00Z], duration: 30)

      assert {:error, :patient_schedule_conflict} =
               Booking.persist_appointment(
                 %{
                   patient_profile_id: ctx.fixture.patient_id,
                   professional_account_id: ctx.fixture.other_professional_id,
                   consultation_type_id: @consultation_type_id,
                   start_time: ~U[2026-10-20 09:15:00Z]
                 },
                 @snapshot
               )

      assert count_appointments(ctx.fixture.professional_id) == 1
    end

    test "persiste turnos contiguos del mismo profesional", ctx do
      assert {:ok, _} =
               Booking.persist_appointment(appointment_attrs(ctx, ~U[2026-10-20 09:00:00Z]))

      assert {:ok, _} =
               Booking.persist_appointment(
                 %{
                   appointment_attrs(ctx, ~U[2026-10-20 09:30:00Z])
                   | patient_profile_id: ctx.fixture.other_patient_id
                 },
                 @snapshot
               )

      assert count_appointments(ctx.fixture.professional_id) == 2
    end

    test "permite re-reservar el slot de un turno cancelado", ctx do
      assert {:ok, _} =
               Booking.persist_appointment(
                 appointment_attrs(ctx, ~U[2026-10-20 09:00:00Z], "cancelled")
               )

      assert {:ok, _} =
               Booking.persist_appointment(
                 %{
                   appointment_attrs(ctx, ~U[2026-10-20 09:00:00Z])
                   | patient_profile_id: ctx.fixture.other_patient_id
                 },
                 @snapshot
               )

      assert count_appointments(ctx.fixture.professional_id) == 2
    end
  end

  describe "restricciones de exclusión de PostgreSQL" do
    test "el INSERT directo que solapa la agenda del profesional es rechazado con 23P01", ctx do
      raw_insert_appointment!(ctx, ~U[2026-10-20 09:00:00Z], 30, "reserved", patient: :main)

      exception =
        assert_raise Postgrex.Error, fn ->
          Repo.transaction(fn ->
            raw_insert_appointment!(ctx, ~U[2026-10-20 09:15:00Z], 30, "reserved")
          end)
        end

      assert exception.postgres.pg_code == "23P01"
      assert exception.postgres.constraint == "appointments_no_professional_overlap"
      assert count_appointments(ctx.fixture.professional_id) == 1
    end

    test "el INSERT directo que solapa al paciente con otro profesional es rechazado con 23P01",
         ctx do
      raw_insert_appointment!(ctx, ~U[2026-10-20 09:00:00Z], 30, "reserved", patient: :main)

      exception =
        assert_raise Postgrex.Error, fn ->
          Repo.transaction(fn ->
            raw_insert_appointment!(
              ctx,
              ~U[2026-10-20 09:15:00Z],
              30,
              "reserved",
              professional: :other,
              patient: :main
            )
          end)
        end

      assert exception.postgres.pg_code == "23P01"
      assert exception.postgres.constraint == "appointments_no_patient_overlap"
      assert count_appointments(ctx.fixture.professional_id) == 1
    end

    test "el INSERT directo contiguo y el que solapa un turno cancelado son aceptados", ctx do
      raw_insert_appointment!(ctx, ~U[2026-10-20 09:00:00Z], 30, "cancelled")

      raw_insert_appointment!(ctx, ~U[2026-10-20 09:00:00Z], 30, "reserved", patient: :main)
      raw_insert_appointment!(ctx, ~U[2026-10-20 09:30:00Z], 30, "reserved")

      assert count_appointments(ctx.fixture.professional_id) == 3
    end
  end

  defp insert_fixture! do
    professional_id = insert_professional!("dr.overlap@example.com")
    other_professional_id = insert_professional!("dr.other-overlap@example.com")

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.consultation_types (
          id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at
        ) VALUES (
          $1, $2, 'Consulta Overlap', 15000.00, '#112233', 1, 'active', clock_timestamp(), clock_timestamp()
        )
        """,
        [Ecto.UUID.dump!(@consultation_type_id), professional_id]
      )

    patient_id = insert_patient!("Juan", "Perez", "30111222", "juan.overlap@example.com")
    other_patient_id = insert_patient!("Ana", "Gomez", "30222333", "ana.overlap@example.com")

    %{
      professional_id: professional_id,
      other_professional_id: other_professional_id,
      consultation_type_id: @consultation_type_id,
      patient_id: patient_id,
      other_patient_id: other_patient_id
    }
  end

  defp insert_professional!(email) do
    {:ok, %{rows: [[id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES ($1, 'professional', 'active', 'hashed_pass_placeholder', decode('010203', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [email]
      )

    id
  end

  defp insert_patient!(first_name, last_name, document_number, email) do
    {:ok, %{rows: [[persona_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
        VALUES ($1, $2, 'dni', $3, '1990-01-01', clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [first_name, last_name, document_number]
      )

    {:ok, %{rows: [[profile_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.patient_profiles (persona_id, email, state, phone, phone_verified, created_at, updated_at)
        VALUES ($1, $2, 'completed', '+5491100001111', true, clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        [persona_id, email]
      )

    profile_id
  end

  defp appointment_attrs(ctx, start_time, status \\ "reserved") do
    %{
      patient_profile_id: ctx.fixture.other_patient_id,
      professional_account_id: ctx.fixture.professional_id,
      consultation_type_id: ctx.fixture.consultation_type_id,
      start_time: start_time,
      status: status
    }
  end

  defp check_params(ctx, start_time, duration) do
    %{
      professional_account_id: ctx.fixture.professional_id,
      patient_profile_id: ctx.fixture.patient_id,
      start_time: start_time,
      end_time: DateTime.add(start_time, duration, :minute)
    }
  end

  defp snapshot(duration) do
    %{@snapshot | duration_minutes: duration}
  end

  defp persist!(ctx, opts) do
    patient = Keyword.get(opts, :patient, :main)

    patient_id =
      if patient == :main, do: ctx.fixture.patient_id, else: ctx.fixture.other_patient_id

    duration = Keyword.get(opts, :duration, 30)

    Booking.persist_appointment(
      %{
        patient_profile_id: patient_id,
        professional_account_id: ctx.fixture.professional_id,
        consultation_type_id: ctx.fixture.consultation_type_id,
        start_time: Keyword.fetch!(opts, :start_time)
      },
      snapshot(duration)
    )
  end

  defp raw_insert_appointment!(ctx, start_time, duration, status, opts \\ []) do
    patient_opt = Keyword.get(opts, :patient, :other)
    professional_opt = Keyword.get(opts, :professional, :main)

    patient_id =
      if patient_opt == :main, do: ctx.fixture.patient_id, else: ctx.fixture.other_patient_id

    professional_id =
      if professional_opt == :main,
        do: ctx.fixture.professional_id,
        else: ctx.fixture.other_professional_id

    Ecto.Adapters.SQL.query!(
      Repo,
      """
      INSERT INTO public.appointments (
        patient_profile_id, professional_account_id, consultation_type_id,
        start_time, end_time, status,
        snapshot_consultation_type_name, snapshot_duration_minutes, snapshot_exact_price_ars
      ) VALUES ($1, $2, $3, $4, $5, $6, 'Consulta Directa', $7, 100.00)
      """,
      [
        patient_id,
        professional_id,
        Ecto.UUID.dump!(ctx.fixture.consultation_type_id),
        start_time,
        DateTime.add(start_time, duration, :minute),
        status,
        duration
      ]
    )
  end

  defp count_appointments(professional_id) do
    {:ok, %{rows: [[count]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        "SELECT count(*) FROM public.appointments WHERE professional_account_id = $1",
        [professional_id]
      )

    count
  end
end

defmodule Origen.Booking.OverlapConcurrencyTest do
  @moduledoc """
  Prueba de carrera real por el mismo slot con conexiones concurrentes (Issue #65).

  Sigue el patrón de `Origen.ConsultationTypesConcurrencyTest`: conexiones sin
  sandbox (`sandbox: false`) con datos realmente confirmados y limpieza explícita.
  N procesos sincronizados por barrera intentan reservar exactamente el mismo
  intervalo del mismo profesional; la restricción de exclusión GiST debe dejar
  exactamente un turno ganador y rechazar al resto con `{:error, :slot_already_booked}`.
  """

  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Repo

  @racer_count 8
  @slot_start ~U[2026-11-03 09:00:00Z]
  @slot_end ~U[2026-11-03 09:30:00Z]

  @snapshot %{
    name: "Consulta Carrera",
    duration_minutes: 30,
    exact_price_ars: Decimal.new("100.00")
  }

  test "reservas simultáneas del mismo slot dejan exactamente un turno" do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    fixture = insert_race_fixture!(@racer_count)

    on_exit(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        cleanup_race_fixture!(fixture)
      after
        Sandbox.checkin(Repo)
      end
    end)

    parent = self()

    tasks =
      for index <- 1..@racer_count do
        Task.async(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          send(parent, {:ready, index})

          receive do
            :go -> :ok
          after
            5_000 -> exit(:barrier_timeout)
          end

          try do
            Booking.persist_appointment(
              %{
                patient_profile_id: Enum.at(fixture.patient_ids, index - 1),
                professional_account_id: fixture.professional_id,
                consultation_type_id: fixture.consultation_type_id,
                start_time: @slot_start,
                status: "reserved"
              },
              @snapshot
            )
          after
            Sandbox.checkin(Repo)
          end
        end)
      end

    Enum.each(1..@racer_count, fn index ->
      assert_receive {:ready, ^index}, 5_000
    end)

    Enum.each(tasks, fn task -> send(task.pid, :go) end)

    results = Task.await_many(tasks, 15_000)

    {winners, losers} = Enum.split_with(results, &match?({:ok, _}, &1))

    assert length(winners) == 1
    assert [{:ok, %Appointment{}}] = winners
    assert length(losers) == @racer_count - 1
    assert Enum.all?(losers, &(&1 == {:error, :slot_already_booked}))

    [[window_rows]] =
      Repo.query!(
        """
        SELECT count(*) FROM public.appointments
        WHERE professional_account_id = $1
          AND start_time = $2 AND end_time = $3
          AND status NOT IN ('cancelled', 'rejected')
        """,
        [fixture.professional_id, @slot_start, @slot_end]
      ).rows

    assert window_rows == 1

    [[professional_rows]] =
      Repo.query!(
        "SELECT count(*) FROM public.appointments WHERE professional_account_id = $1",
        [fixture.professional_id]
      ).rows

    assert professional_rows == 1

    [[overlapping_pairs]] =
      Repo.query!("""
        SELECT count(*)
        FROM public.appointments a
        JOIN public.appointments b
          ON a.id < b.id
         AND a.professional_account_id = b.professional_account_id
         AND a.status NOT IN ('cancelled', 'rejected')
         AND b.status NOT IN ('cancelled', 'rejected')
         AND tstzrange(a.start_time, a.end_time, '[)') && tstzrange(b.start_time, b.end_time, '[)')
      """).rows

    assert overlapping_pairs == 0
  end

  defp insert_race_fixture!(racer_count) do
    suffix = System.unique_integer([:positive])

    {:ok, %{rows: [[professional_id]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.internal_accounts (email, role, state, password_hash, totp_secret, activated_at, created_at, updated_at)
        VALUES ($1, 'professional', 'active', 'hashed_pass_placeholder', decode('010203', 'hex'), clock_timestamp(), clock_timestamp(), clock_timestamp())
        RETURNING id
        """,
        ["dr.race-#{suffix}@example.com"]
      )

    consultation_type_id = Ecto.UUID.generate()

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        INSERT INTO public.consultation_types (
          id, owner_account_id, name, exact_price_ars, color, interval_count, status, created_at, updated_at
        ) VALUES (
          $1, $2, 'Consulta Carrera', 100.00, '#445566', 1, 'active', clock_timestamp(), clock_timestamp()
        )
        """,
        [Ecto.UUID.dump!(consultation_type_id), professional_id]
      )

    patient_ids =
      Enum.map(1..racer_count, fn index ->
        {:ok, %{rows: [[persona_id]]}} =
          Ecto.Adapters.SQL.query(
            Repo,
            """
            INSERT INTO public.personas (first_name, last_name, document_type, document_number, birthdate, created_at, updated_at)
            VALUES ('Corredor', $1, 'dni', $2, '1990-01-01', clock_timestamp(), clock_timestamp())
            RETURNING id
            """,
            ["Carrera #{index}", Integer.to_string(40_000_000 + suffix * 100 + index)]
          )

        {:ok, %{rows: [[profile_id]]}} =
          Ecto.Adapters.SQL.query(
            Repo,
            """
            INSERT INTO public.patient_profiles (persona_id, email, state, phone, phone_verified, created_at, updated_at)
            VALUES ($1, $2, 'completed', '+5491100002222', true, clock_timestamp(), clock_timestamp())
            RETURNING id
            """,
            [persona_id, "corredor-#{suffix}-#{index}@example.com"]
          )

        profile_id
      end)

    %{
      professional_id: professional_id,
      consultation_type_id: consultation_type_id,
      patient_ids: patient_ids
    }
  end

  # La limpieza respeta el orden de las FK RESTRICT (turnos → tipo de consulta →
  # perfiles → personas → cuenta) y barre además las personas huérfanas propias de
  # este fixture (perfiles ya eliminados) para no dejar estado residual entre corridas.
  defp cleanup_race_fixture!(fixture) do
    persona_ids = fetch_persona_ids(fixture.patient_ids)

    Repo.query!("DELETE FROM public.appointments WHERE professional_account_id = $1", [
      fixture.professional_id
    ])

    Repo.query!(
      "DELETE FROM public.consultation_types WHERE id = $1",
      [Ecto.UUID.dump!(fixture.consultation_type_id)]
    )

    Repo.query!(
      "DELETE FROM public.patient_profiles WHERE id = ANY($1)",
      [fixture.patient_ids]
    )

    Repo.query!(
      """
      DELETE FROM public.personas
      WHERE id = ANY($1)
         OR (
           first_name = 'Corredor'
           AND NOT EXISTS (SELECT 1 FROM public.patient_profiles p WHERE p.persona_id = public.personas.id)
         )
      """,
      [persona_ids]
    )

    Repo.query!("DELETE FROM public.internal_accounts WHERE id = $1", [
      fixture.professional_id
    ])
  end

  defp fetch_persona_ids(patient_ids) do
    {:ok, %{rows: rows}} =
      Ecto.Adapters.SQL.query(
        Repo,
        "SELECT persona_id FROM public.patient_profiles WHERE id = ANY($1)",
        [patient_ids]
      )

    Enum.map(rows, &[hd(&1)])
  end
end

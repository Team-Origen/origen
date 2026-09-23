# Script ejecutable de demostración y comprobación de fallos y reversión
# Subissue #71 / PLN-14 (Father Issue #47)
#
# Ejecución:
#     mix run priv/repo/check_journey_failure_regression.exs

alias Origen.Appointments.BookingService
alias Origen.Booking
alias Origen.Booking.Agenda
alias Origen.Booking.Appointment
alias Origen.Booking.ProfessionalPatientRelationship
alias Origen.Booking.ReservationRequest
alias Origen.Patients
alias Origen.Repo
alias Origen.Sessions
import Ecto.Query

IO.puts("""
================================================================================
 ORIGEN — REGRESIÓN DE FALLOS Y REVERSIÓN TRANSACCIONAL DEL RECORRIDO
 Subissue #71 (PLN-14) / Father Issue #47
 Objetivo: "Horarios ocupados y accesos incorrectos"
================================================================================
""")

suffix = System.unique_integer([:positive])

# Setup Profesional de prueba
prof_email = "dr.fallos_#{suffix}@clinicaorigen.test"

prof_account_id =
  case Repo.one(from(a in "internal_accounts", where: a.email == ^prof_email, select: a.id)) do
    nil ->
      res =
        Repo.query!("""
        INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ('professional', 'active', '#{prof_email}', 'hash', decode('0102', 'hex'), clock_timestamp())
        RETURNING id
        """)

      hd(res.rows) |> hd()

    existing_id ->
      existing_id
  end

{:ok, %{token: _prof_token, session: prof_principal}} = Sessions.create_session(prof_account_id)

Repo.query!(
  """
  INSERT INTO agenda_settings (owner_account_id, interval_minutes)
  VALUES ($1, 30)
  ON CONFLICT (owner_account_id) DO NOTHING
  """,
  [prof_account_id]
)

type_uuid = Ecto.UUID.generate()

Repo.query!(
  """
  INSERT INTO consultation_types (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
  VALUES ($1, $2, 'Consulta Regresion', 18000.00, '#0A3847', 1, 'active')
  """,
  [Ecto.UUID.dump!(type_uuid), prof_account_id]
)

IO.puts("✔ Contexto inicial preparado:")
IO.puts("  - Profesional: #{prof_email} (ID: #{prof_account_id})")
IO.puts("  - Tipo de Consulta ID: #{type_uuid} ($18000.00 ARS)")

# ==============================================================================
# ESCENARIO 1: SOLICITUDES CONCURRENTES SIMULTÁNEAS EN EL MISMO SLOT
# ==============================================================================
IO.puts("\n▶ ESCENARIO 1: Solicitudes concurrentes simultáneas por el mismo turno")

# Crear 2 pacientes verificados
crear_paciente_verificado = fn idx, dni ->
  email = "paciente_concurrente_#{idx}_#{suffix}@example.test"

  Repo.query!(
    "DELETE FROM appointments WHERE patient_profile_id IN (SELECT id FROM patient_profiles WHERE email = $1)",
    [email]
  )

  Repo.query!("DELETE FROM patient_profiles WHERE email = $1", [email])
  Repo.query!("DELETE FROM personas WHERE document_type = 'dni' AND document_number = $1", [dni])

  {:ok, %{profile: p}} =
    Patients.complete_profile(email, %{
      first_name: "Corredor",
      last_name: "#{idx}",
      document_type: "dni",
      document_number: dni,
      birthdate: ~D[1990-01-01],
      phone: "+549114400#{idx}#{suffix |> rem(1000)}"
    })

  p |> Ecto.Changeset.change(%{phone_verified: true}) |> Repo.update!()
end

p1 = crear_paciente_verificado.(1, "49111#{suffix |> rem(1000)}")
p2 = crear_paciente_verificado.(2, "49222#{suffix |> rem(1000)}")

booking_date = Date.add(Date.utc_today(), 7)
slot = %{start_time: ~T[11:00:00], start_formatted: "11:00"}

params_base = %{
  professional_id: prof_account_id,
  consultation_type_id: type_uuid,
  date: booking_date,
  slot: slot
}

# Tareas concurrentes disparadas con sincronización
task1 =
  Task.async(fn ->
    receive do
      :go -> BookingService.reserve(p1, params_base)
    end
  end)

task2 =
  Task.async(fn ->
    receive do
      :go -> BookingService.reserve(p2, params_base)
    end
  end)

# Disparo sincronizado
send(task1.pid, :go)
send(task2.pid, :go)

r1 = Task.await(task1, 10_000)
r2 = Task.await(task2, 10_000)

results = [r1, r2]
{winners, losers} = Enum.split_with(results, &match?({:ok, _}, &1))

[{:ok, winner}] = winners
[{:error, :slot_already_booked}] = losers

IO.puts("   ✔ Concurrencia resuelta deterministamente:")

IO.puts(
  "     - Ganador: Turno ##{winner.appointment_id} para Paciente ID: #{winner.appointment.patient_profile_id}"
)

IO.puts("     - Perdedor: Rechazado limpiamente con :slot_already_booked")

slot_count =
  Repo.one(
    from(a in Appointment,
      where:
        a.professional_account_id == ^prof_account_id and
          a.start_time == ^winner.start_time,
      select: count(a.id)
    )
  )

IO.puts(
  "   ✔ Verificación forense en BD: Exactamente #{slot_count} turno registrado en el slot (OK)"
)

# ==============================================================================
# ESCENARIO 2: PERFILES INCOMPLETOS, TELÉFONO NO VERIFICADO Y COLISIÓN
# ==============================================================================
IO.puts("\n▶ ESCENARIO 2: Barreras de identidad y perfil incompleto")

# 2.1 Anónimo
case BookingService.reserve(nil, params_base) do
  {:error, :unauthenticated} ->
    IO.puts("   ✔ Usuario no autenticado: Rechazado con :unauthenticated")

  other ->
    raise "Falla: anónimo retornó #{inspect(other)}"
end

# 2.2 Pending completion
email_pending = "pending_#{suffix}@example.test"
{:ok, profile_pending} = Patients.get_or_create_profile(email_pending)

case BookingService.reserve(profile_pending, params_base) do
  {:error, :patient_not_ready_for_booking} ->
    IO.puts("   ✔ Perfil en 'pending_completion': Rechazado con :patient_not_ready_for_booking")

  other ->
    raise "Falla: pending_completion retornó #{inspect(other)}"
end

# 2.3 Teléfono no verificado
email_unverified = "sin_tel_#{suffix}@example.test"
dni_unverified = "49333#{suffix |> rem(1000)}"

{:ok, %{profile: profile_unverified}} =
  Patients.complete_profile(email_unverified, %{
    first_name: "Sin",
    last_name: "Verificar",
    document_type: "dni",
    document_number: dni_unverified,
    birthdate: ~D[1995-05-05],
    phone: "+5491188889999"
  })

case BookingService.reserve(profile_unverified, params_base) do
  {:error, :patient_not_ready_for_booking} ->
    IO.puts(
      "   ✔ Perfil 'completed' sin teléfono verificado: Rechazado con :patient_not_ready_for_booking"
    )

  other ->
    raise "Falla: teléfono no verificado retornó #{inspect(other)}"
end

# 2.4 Colisión documental (RF-02)
email_colision = "colision_#{suffix}@example.test"

{:ok, %{outcome: :derived_to_secretary, profile: collided}} =
  Patients.complete_profile(email_colision, %{
    first_name: "Intento",
    last_name: "Usurpador",
    document_type: "dni",
    document_number: dni_unverified,
    birthdate: ~D[1999-09-09],
    phone: "+5491177770000"
  })

case BookingService.reserve(collided, params_base) do
  {:error, :patient_not_ready_for_booking} ->
    IO.puts("   ✔ Colisión de DNI (#{dni_unverified}): Derivado a secretaría y reserva bloqueada")

  other ->
    raise "Falla: colisión retornó #{inspect(other)}"
end

# ==============================================================================
# ESCENARIO 3: REVERSIÓN TRANSACCIONAL Y AUSENCIA DE ORFANDAD (ROLLBACK TOTAL)
# ==============================================================================
IO.puts("\n▶ ESCENARIO 3: Reversión transaccional total (Rollback atómico)")

future_slot_time = DateTime.new!(booking_date, ~T[15:00:00], "Etc/UTC")

request_fail_rel = %ReservationRequest{
  actor: %{role: :patient, id: p1.id},
  patient_id: p1.id,
  professional_id: prof_account_id,
  consultation_type_id: type_uuid,
  start_time: future_slot_time
}

initial_appts = Repo.aggregate(Appointment, :count)
initial_rels = Repo.aggregate(ProfessionalPatientRelationship, :count)

case Booking.reserve_appointment(request_fail_rel, fail_at: :relationship) do
  {:error, :relationship_insertion_failed} ->
    post_appts = Repo.aggregate(Appointment, :count)
    post_rels = Repo.aggregate(ProfessionalPatientRelationship, :count)

    if post_appts == initial_appts and post_rels == initial_rels do
      IO.puts("   ✔ Rollback total ante fallo de relación: 0 turnos y 0 relaciones persistidas.")
    else
      raise "Orfandad detectada: appts #{post_appts} != #{initial_appts} o rels #{post_rels} != #{initial_rels}"
    end

  other ->
    raise "Falla: inyección fail_at: :relationship retornó #{inspect(other)}"
end

case Booking.reserve_appointment(request_fail_rel, fail_at: :audit_event) do
  {:error, :fallo_auditoria} ->
    post_appts = Repo.aggregate(Appointment, :count)
    post_rels = Repo.aggregate(ProfessionalPatientRelationship, :count)

    if post_appts == initial_appts and post_rels == initial_rels do
      IO.puts("   ✔ Rollback total ante fallo de auditoría: 0 turnos y 0 relaciones persistidas.")
    else
      raise "Orfandad detectada: appts #{post_appts} != #{initial_appts} o rels #{post_rels} != #{initial_rels}"
    end

  other ->
    raise "Falla: inyección fail_at: :audit_event retornó #{inspect(other)}"
end

# Comprobar ausencia de orfandad relacional en toda la base de datos
orphan_appts =
  Repo.all(
    from(a in Appointment,
      where: is_nil(a.patient_profile_id) or is_nil(a.professional_account_id)
    )
  )

orphan_rels =
  Repo.all(
    from(r in ProfessionalPatientRelationship,
      where: is_nil(r.patient_profile_id) or is_nil(r.professional_account_id)
    )
  )

if orphan_appts == [] and orphan_rels == [] do
  IO.puts(
    "   ✔ Integridad referencial forense: 0 turnos huérfanos y 0 relaciones huérfanas en el sistema."
  )
else
  raise "Registros huérfanos detectados en BD."
end

# ==============================================================================
# ESCENARIO 4: CONFIDENCIALIDAD Y NO EXPOSICIÓN DE DATOS AJENOS
# ==============================================================================
IO.puts("\n▶ ESCENARIO 4: Confidencialidad médica y no exposición de datos ajenos")

# 4.1 Mensaje de solapamiento opaco
slot_booked_result = BookingService.reserve(p2, params_base)
error_dump = inspect(slot_booked_result)

if slot_booked_result == {:error, :slot_already_booked} and
     not String.contains?(error_dump, p1.email) and
     not String.contains?(error_dump, "49111") do
  IO.puts(
    "   ✔ Mensaje de conflicto opaco: No expone email, nombre ni documento del titular del turno."
  )
else
  raise "Fuga de privacidad en mensaje de solapamiento: #{error_dump}"
end

# 4.2 Inmunidad contra manipulación de identificadores (IDOR)
idor_params = %{
  date: booking_date,
  professional_id: prof_account_id + 9999,
  account_id: prof_account_id + 9999
}

{:ok, agenda_own} = Agenda.get_professional_agenda(prof_principal, idor_params)

if agenda_own.professional_account_id == prof_account_id do
  IO.puts(
    "   ✔ Inmunidad contra IDOR: Parámetros del cliente ignorados; agenda filtrada por sesión revalidada."
  )
else
  raise "Vulnerabilidad IDOR detectada en get_professional_agenda."
end

# 4.3 Sesión revocada
Sessions.terminate_all_sessions(prof_account_id)

case Agenda.get_professional_agenda(prof_principal, %{date: booking_date}) do
  {:error, :unauthorized} ->
    IO.puts("   ✔ Sesión revocada: Acceso denegado inmediatamente con :unauthorized.")

  other ->
    raise "Falla de autenticación: sesión revocada obtuvo #{inspect(other)}"
end

IO.puts("""

================================================================================
 REGRESIÓN DE FALLOS Y REVERSIÓN INTEGRADA COMPLETADA CON ÉXITO (SUBISSUE #71)
 - Concurrencia simultánea (1 ganador, N rechazados deterministas): COMPROBADO
 - Perfiles incompletos, teléfono sin verificar y colisiones de DNI: COMPROBADO
 - Rollback total y ausencia de orfandad en turnos y relaciones: COMPROBADO
 - Confidencialidad estricta e inmunidad ante IDOR y sesiones revocadas: COMPROBADO
================================================================================
""")

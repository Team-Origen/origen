alias Origen.Appointments.BookingService
alias Origen.Booking.Appointment
alias Origen.Patients
alias Origen.Repo
import Ecto.Query

IO.puts("\n=== PRUEBA DE RESERVA AUTÓNOMA DE PUNTA A PUNTA (SUBISSUE #93) ===")

# 1. Obtener o crear paciente con perfil verificado
patient_email = "ana.gomez@example.test"

{:ok, %{profile: profile}} =
  Patients.complete_profile(patient_email, %{
    first_name: "Ana",
    last_name: "Gómez",
    document_type: "dni",
    document_number: "38123456",
    birthdate: ~D[1994-05-20],
    phone: "+5491133445566"
  })

verified_profile =
  profile
  |> Ecto.Changeset.change(%{phone_verified: true})
  |> Repo.update!()

IO.puts("1. Paciente autenticado y verificado: #{verified_profile.email}")
IO.puts("   -> Teléfono verificado: #{verified_profile.phone_verified}")
IO.puts("   -> ready_for_booking?: #{Patients.ready_for_booking?(verified_profile)}")

# 2. Obtener profesional activo
prof =
  case Repo.one(
         from a in "internal_accounts",
           where: a.role == "professional" and a.state == "active",
           select: %{id: a.id, email: a.email},
           limit: 1
       ) do
    nil ->
      res =
        Repo.query!("""
        INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
        VALUES ('professional', 'active', 'dra.martinez@example.test', 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """)

      %{id: hd(res.rows) |> hd(), email: "dra.martinez@example.test"}

    found ->
      found
  end

IO.puts("\n2. Profesional de atención: #{prof.email} (ID: #{prof.id})")

# 3. Obtener o insertar tipo de consulta
type_uuid = "018f4a5b-0d62-7a44-8e32-2f608bfcb001"

case Repo.query("SELECT id FROM consultation_types WHERE id = $1", [Ecto.UUID.dump!(type_uuid)]) do
  {:ok, %{rows: [[_]]}} ->
    :ok

  _ ->
    Repo.query!(
      """
      INSERT INTO consultation_types (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, 'Consulta general', 18000.00, '#0A3847', 2, 'active')
      ON CONFLICT (id) DO NOTHING
      """,
      [Ecto.UUID.dump!(type_uuid), prof.id]
    )
end

IO.puts("\n3. Tipo de consulta seleccionado: Consulta general ($18000.00, 30 min)")

# 4. Ejecutar reserva autónoma mediante BookingService (cita futura > 24hs -> RF-10 'reserved')
future_date = Date.add(Date.utc_today(), 5)
slot = %{start_time: ~T[10:00:00], start_formatted: "10:00"}

params = %{
  professional_id: prof.id,
  consultation_type_id: type_uuid,
  date: future_date,
  slot: slot,
  snapshot_override: %{
    name: "Consulta general",
    duration_minutes: 30,
    exact_price_ars: Decimal.new("18000.00")
  }
}

IO.puts("\n4. Ejecutando reserva autónoma para el día #{future_date} a las 10:00 hs...")
{:ok, result} = BookingService.reserve(verified_profile, params)

IO.puts("\n5. Resultado de la reserva:")
IO.puts("   -> ID del Turno: ##{result.appointment_id}")
IO.puts("   -> Estado inicial (RF-10): #{result.status}")
IO.puts("   -> Tipo de Consulta (Snapshot): #{result.consultation_type_name}")
IO.puts("   -> Duración: #{result.duration_minutes} min")
IO.puts("   -> Precio exacto (ARS): $#{result.exact_price_ars}")
IO.puts("   -> Horario inicio: #{result.start_time}")
IO.puts("   -> Horario fin: #{result.end_time}")

# 6. Corroborar persistencia en PostgreSQL
persisted = Repo.get!(Appointment, result.appointment_id)
IO.puts("\n6. Corroboración forense en tabla 'appointments':")
IO.puts("   -> Persistido con ID: #{persisted.id}")
IO.puts("   -> Paciente ID: #{persisted.patient_profile_id}")
IO.puts("   -> Profesional ID: #{persisted.professional_account_id}")
IO.puts("   -> Estado en BD: #{persisted.status}")
IO.puts("   -> Snapshot Nombre: #{persisted.snapshot_consultation_type_name}")
IO.puts("   -> Snapshot Precio: $#{persisted.snapshot_exact_price_ars}")

IO.puts("\n=== PRUEBA DE RESERVA AUTÓNOMA COMPLETADA CON ÉXITO ===\n")

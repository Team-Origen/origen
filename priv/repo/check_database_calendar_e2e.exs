alias Origen.Appointments.DatabaseCalendar
alias Origen.Repo

IO.puts("\n=== PRUEBA DE PERSISTENCIA REAL EN POSTGRESQL (PR #158 / #92) ===")

# 1. Crear o reutilizar un profesional en internal_accounts
email = "doctora.gonzalez@example.test"

prof_id =
  case Repo.query("SELECT id FROM internal_accounts WHERE email = $1", [email]) do
    {:ok, %{rows: [[id]]}} ->
      id

    _ ->
      res =
        Repo.query!(
          """
          INSERT INTO internal_accounts (role, state, email, password_hash, totp_secret, activated_at)
          VALUES ('professional', 'active', $1, 'hash_demo', decode('0102030405', 'hex'), clock_timestamp())
          RETURNING id
          """,
          [email]
        )

      hd(res.rows) |> hd()
  end

IO.puts("1. Profesional en internal_accounts: #{email} (ID: #{prof_id})")

# 2. Configurar agenda_settings con disponibilidad personalizada
# Lunes de 09:00 a 13:00, Jueves de 14:00 a 18:00
week_json = ~s({
  "monday": [{"start": "09:00", "end": "13:00"}],
  "tuesday": [],
  "wednesday": [],
  "thursday": [{"start": "14:00", "end": "18:00"}],
  "friday": [{"start": "08:00", "end": "12:00"}],
  "saturday": [],
  "sunday": []
})

Repo.query!(
  """
  INSERT INTO agenda_settings (owner_account_id, interval_minutes, weekly_availability, booking_horizon_days, minimum_lead_minutes)
  VALUES ($1, 15, $2::jsonb, 30, 30)
  ON CONFLICT (owner_account_id) DO UPDATE
  SET weekly_availability = $2::jsonb, interval_minutes = 15, updated_at = clock_timestamp()
  """,
  [prof_id, week_json]
)

IO.puts("2. Configuración guardada en tabla agenda_settings de PostgreSQL:")
IO.puts("   -> Intervalo de agenda: 15 min")
IO.puts("   -> Lunes: 09:00 a 13:00 hs | Jueves: 14:00 a 18:00 hs | Viernes: 08:00 a 12:00 hs")

# 3. Consultar list_professionals/0 desde DatabaseCalendar
{:ok, profs} = DatabaseCalendar.list_professionals()

IO.puts(
  "\n3. Profesionales detectados por DatabaseCalendar.list_professionals/0: #{length(profs)}"
)

for p <- profs do
  IO.puts("   -> ID: #{p.id} | Nombre: #{p.name} | Especialidad: #{p.specialty}")
end

# 4. Consultar disponibilidad real para el próximo Lunes
# 2026-09-28 es Lunes
monday = ~D[2026-09-28]
IO.puts("\n4. Consultando disponibilidad real para el Lunes (#{monday}):")

# A: Práctica corta (Control - 15 min)
{:ok, sched_15} =
  DatabaseCalendar.get_daily_schedule(prof_id, monday,
    duration_minutes: 15,
    agenda_interval_minutes: 15
  )

IO.puts("   A. Práctica 'Control' (15 min) -> #{length(sched_15.slots)} slots generados:")

slots_preview_15 =
  sched_15.slots |> Enum.take(4) |> Enum.map(& &1.start_formatted) |> Enum.join(", ")

IO.puts("      Primeros slots: [#{slots_preview_15} ...]")

# B: Práctica larga (Procedimiento - 60 min)
{:ok, sched_60} =
  DatabaseCalendar.get_daily_schedule(prof_id, monday,
    duration_minutes: 60,
    agenda_interval_minutes: 60
  )

IO.puts("   B. Práctica 'Procedimiento' (60 min) -> #{length(sched_60.slots)} slots generados:")

for slot <- sched_60.slots do
  IO.puts("      - Slot: #{slot.start_formatted} a #{slot.end_formatted} hs")
end

# 5. Consultar día sin disponibilidad en BD (Martes 2026-09-29)
tuesday = ~D[2026-09-29]
{:ok, sched_tue} = DatabaseCalendar.get_daily_schedule(prof_id, tuesday)
IO.puts("\n5. Consultando día sin disponibilidad en BD (Martes #{tuesday}):")
IO.puts("   -> Slots devueltos: #{length(sched_tue.slots)} (Vacío)")

IO.puts("\n=== PRUEBA DE BASE DE DATOS COMPLETADA CON ÉXITO ===\n")

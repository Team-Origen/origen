alias Origen.Patients
alias Origen.Patients.PhoneVerificationChallenge
alias Origen.Repo
import Ecto.Query

test_email = "paciente.prueba.89@example.test"
test_phone = "+54 9 11 4455-6677"

IO.puts("
=== PRUEBA LOCAL DE EMISIÓN DE DESAFÍO TELEFÓNICO (SUBISSUE #89) ===")

# 1. Asegurar perfil de paciente existente
{:ok, profile} = Patients.get_or_create_profile(test_email)
Repo.delete_all(from c in PhoneVerificationChallenge, where: c.patient_profile_id == ^profile.id)

IO.puts(
  "1. Perfil de Paciente: #{profile.email} (ID: #{profile.id}) (Desafíos previos limpiados para prueba)"
)

# 2. Solicitar emisión de desafío
IO.puts("
2. Solicitando emisión de desafío para el teléfono: #{test_phone}...")

case Patients.request_phone_verification(profile, test_phone, return_code: true) do
  {:ok, %{challenge: ch, delivery: :delivered, code: plain_code}} ->
    IO.puts("   -> Desafío emitido con éxito!")
    IO.puts("   -> ID Desafío en BD: #{ch.id}")
    IO.puts("   -> Teléfono normalizado: #{ch.phone}")
    IO.puts("   -> Código en texto plano (en memoria/mail): #{plain_code}")
    IO.puts("   -> Código almacenado en BD (Hash SHA-256): #{ch.code_hash}")
    IO.puts("   -> Estado del desafío: #{ch.state}")
    IO.puts("   -> Vence en: #{ch.expires_at}")

    # Verificar que el código plano NO está en la base de datos
    raw_found = Repo.get_by(PhoneVerificationChallenge, code_hash: plain_code)
    IO.puts("   -> ¿Código en texto plano existe en BD?: #{raw_found != nil} (Debe ser false)")

  {:error, reason} ->
    IO.puts("   -> Error inesperado: #{inspect(reason)}")
end

# 3. Probar regla de Cooldown (intentar de inmediato)
IO.puts("
3. Probando Cooldown de 60 segundos (solicitud inmediata posterior)...")

case Patients.request_phone_verification(profile, test_phone) do
  {:error, :cooldown_active} ->
    IO.puts(
      "   -> Cooldown verificado con éxito! El sistema frenó la solicitud (error: :cooldown_active)"
    )

  other ->
    IO.puts("   -> Resultado inesperado en cooldown: #{inspect(other)}")
end

# 4. Inspeccionar Evento de Auditoría
IO.puts("
4. Verificando auditoría en la tabla audit_events...")

audit_event =
  Repo.one(
    from a in "audit_events",
      where: a.event == "phone_challenge_issued" and a.entity_ref == ^test_email,
      order_by: [desc: a.id],
      limit: 1,
      select: %{event: a.event, result: a.result, entity_ref: a.entity_ref}
  )

if audit_event do
  IO.puts(
    "   -> Evento registrado: #{audit_event.event} | Resultado: #{audit_event.result} | Ref: #{audit_event.entity_ref}"
  )
else
  IO.puts("   -> Advertencia: No se encontró evento de auditoría.")
end

IO.puts("
=== PRUEBA LOCAL COMPLETADA CON ÉXITO ===
")

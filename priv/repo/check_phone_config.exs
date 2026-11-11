alias Origen.Patients.PhoneVerificationConfig, as: Config

IO.puts("
=== 1. GENERACIÓN CRIPTOGRÁFICA DE CÓDIGOS (6 DÍGITOS) ===")
for i <- 1..3 do
  code = Config.generate_code()
  IO.puts("  Intento #{i}: #{code} (longitud: #{String.length(code)}, numérico: #{Regex.match?(~r/^[0-9]{6}$/, code)})")
end

IO.puts("
=== 2. HASHING SHA-256 Y VERIFICACIÓN EN TIEMPO CONSTANTE ===")
sample_code = "849201"
hash = Config.hash_code(sample_code)
IO.puts("  Código en texto plano: #{sample_code}")
IO.puts("  Hash seguro (en reposo): #{hash}")
IO.puts("  ¿Verificación con código correcto (849201)?: #{Config.verify_code_hash("849201", hash)}")
IO.puts("  ¿Verificación con código incorrecto (000000)?: #{Config.verify_code_hash("000000", hash)}")

IO.puts("
=== 3. PRIVACIDAD: SANITIZACIÓN DE TELÉFONOS PARA LOGS Y AUDITORÍA ===")
phones = [
  "+5491133445566",
  "+54 9 11 3344-5566",
  "123"
]
for phone <- phones do
  IO.puts("  Original: #{String.pad_trailing(phone, 20)} -> Enmascarado: #{Config.sanitize_phone(phone)}")
end

IO.puts("
=== 4. CANAL Y CANDADO DE PRODUCCIÓN (FAIL-CLOSED) ===")
IO.puts("  Canal en :dev:  #{inspect(Config.channel_for_environment(:dev))}")
IO.puts("  Canal en :test: #{inspect(Config.channel_for_environment(:test))}")
IO.puts("  Canal en :prod: #{inspect(Config.channel_for_environment(:prod))} (Rechazo seguro)")
IO.puts("  Validación de Twilio en :dev: #{inspect(Config.validate_channel_config(%{environment: :dev, channel: :twilio}))} (Rechazado)
")

# Tasks: Issue #90 - Implementar validación y consumo del desafío telefónico

Padre: #48 (PLN-15: Verificar el teléfono del Paciente)
Responsable: Samuel (@samuel-olmos)
Revisor: Said (@Saidqr)
Estrategia: Stacked PRs en 2 capas (≤ 400 líneas por PR)
- Stack PR 1/2: Backend Core (Seguridad, Consumo Atómico y Pruebas de Dominio)
- Stack PR 2/2: Frontend LiveView (Pantalla de Verificación y Flujo de UI)

## Criterios de Aceptación
- [ ] Valida que el desafío corresponda a la misma cuenta y número.
- [ ] Consume el desafío de forma atómica e impide reutilizarlo.
- [ ] Marca el teléfono como verificado únicamente después de una validación exitosa.
- [ ] Rechaza desafíos vencidos, consumidos o fuera del límite de intentos y audita el resultado sanitizado.

## Tareas

### Capa 1: Backend Core (PR 1/2) - Rama `feature/90-phone-verification-core`
- [ ] 1. Agregar eventos de auditoría `phone_challenge_consumed` y `phone_challenge_failed` en `Origen.Audit.Events`.
- [ ] 2. Implementar `Origen.Patients.verify_phone_code/3` con comparación en tiempo constante, control de expiración, límite de 3 intentos, consumo atómico y marcado de `phone_verified: true`.
- [ ] 3. Escribir suite de pruebas de seguridad y consumo en `test/origen/patients/phone_verification_consumption_test.exs`.
- [ ] 4. Verificar formato y tests locales (`mix format`, `mix test`).
- [ ] 5. Abrir Stack PR 1/2 contra `develop`, asignar revisor y validar CI.

### Capa 2: Frontend LiveView (PR 2/2) - Rama `feature/90-phone-verification-liveview`
- [ ] 6. Implementar `OrigenWeb.PatientPhoneVerificationLive` en `/patient/phone/verify` con PetalComponents y estados de error/éxito.
- [ ] 7. Registrar ruta en `lib/origen_web/router.ex` y escribir tests en `test/origen_web/live/patient_phone_verification_live_test.exs`.
- [ ] 8. Abrir Stack PR 2/2 contra `feature/90-phone-verification-core`, asignar revisor y validar CI.

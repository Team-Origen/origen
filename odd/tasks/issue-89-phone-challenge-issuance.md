# Tasks: Issue #89 - Implementar emisión y entrega del desafío telefónico

Padre: #48 (PLN-15: Verificar el teléfono del Paciente)
Responsable: Samuel (@samuel-olmos)
Revisor: Said (@Saidqr)
Rama: `feature/89-phone-challenge-issuance`

## Criterios de Aceptación
- [ ] Genera el desafío y almacena únicamente una representación protegida con caducidad.
- [ ] Entrega el desafío mediante el canal acordado en #88 (Swoosh local / email del paciente).
- [ ] Aplica límites de frecuencia e intentos definidos (cooldown 60s, máx 5/hora).
- [ ] Audita la solicitud sin exponer el código ni el número completo.

## Tareas
- [ ] 1. Crear migración y esquema Ecto `phone_verification_challenges` (código hash, expiración, estado, intentos).
- [ ] 2. Implementar módulo de correo `Origen.Patients.PhoneVerificationEmail` usando Swoosh para el canal local acordado en #88.
- [ ] 3. Agregar lógica de emisión, rate limiting (cooldown y cuota horaria) y expiración previa en `Origen.Patients.request_phone_verification/3`.
- [ ] 4. Registrar evento de auditoría sanitizado `phone_verification_challenge_issued` en `Origen.Audit.Events`.
- [ ] 5. Escribir suite de pruebas de integración y seguridad en `test/origen/patients/phone_verification_issuance_test.exs`.
- [ ] 6. Formatear y verificar localmente con `mix test` y `mix format --check-formatted`.
- [ ] 7. Abrir PR enlazado (`Closes #89`), solicitar revisión a @Saidqr y verificar CI en GitHub Actions.

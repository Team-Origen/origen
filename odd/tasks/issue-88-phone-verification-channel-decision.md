# Tasks: Issue #88 - Decidir el canal de desarrollo para desafíos telefónicos

Padre: #48 (PLN-15: Verificar el teléfono del Paciente)
Responsable: Samuel (@samuel-olmos)
Revisor: Said (@Saidqr)
Rama: `feature/88-phone-verification-channel-decision`

## Criterios de Aceptación
- [ ] Documenta la decisión del canal no productivo para entregar desafíos telefónicos en desarrollo.
- [ ] Define expiración, un solo uso, límite de intentos y protección del código almacenado.
- [ ] Prohíbe registrar códigos o números completos en auditoría y logs.
- [ ] Mantiene cerradas las configuraciones productivas mientras no exista autorización específica.

## Tareas
- [ ] 1. Crear documento de decisión y especificación de seguridad `docs/security/PHONE_VERIFICATION_CHALLENGE_DESIGN.md`.
- [ ] 2. Implementar módulo puro `Origen.Patients.PhoneVerificationConfig` con constantes, sanitización de teléfonos, hash de código y validación fail-closed de canal.
- [ ] 3. Escribir suite de pruebas unitarias en `test/origen/patients/phone_verification_config_test.exs`.
- [ ] 4. Validar formato, compilación y tests con `mix format --check-formatted` y `mix test`.
- [ ] 5. Crear rama, hacer commit, push, abrir PR enlazado (`Closes #88`), asignar revisor y verificar CI en GitHub Actions.

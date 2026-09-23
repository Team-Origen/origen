# Runbook y Reporte Durable de la Demo Integrada

> **Father Issue:** [#47](https://github.com/Team-Origen/origen/issues/47) — PLN-14: Integración temprana y ensayo seguro  
> **Subissues asociadas:** [#70](https://github.com/Team-Origen/origen/issues/70) (Recorrido principal), [#71](https://github.com/Team-Origen/origen/issues/71) (Regresión de fallos y reversión), [#72](https://github.com/Team-Origen/origen/issues/72) (Runbook y reporte)  
> **Destinatarios:** Equipo de desarrollo, docentes evaluadores y revisores técnicos.  
> **Estado:** Aprobado / Verificado con datos 100% ficticios y reproducibles.

---

## 1. Objetivo de la Demostración

Demostrar en un entorno local reproducible la viabilidad técnica y arquitectónica del núcleo de **Origen** para el cierre del Sprint 1:
1. **Recorrido feliz extremo a extremo:** Un profesional configura su disponibilidad y servicios, un paciente accede sin contraseña vía Magic Link, completa su identidad, valida su teléfono, reserva un turno disponible de forma autónoma, y el profesional visualiza inmediatamente el turno reflejado en su agenda diaria interactiva.
2. **Garantías de seguridad e integridad:** Demostrar que el sistema no relaja ninguna regla de negocio bajo condiciones adversas: aislamiento estricto entre profesionales, reversión transaccional completa ante conflictos de concurrencia, bloqueo mandatorio ante perfiles incompletos o teléfonos sin verificar, e inmunidad ante manipulación de parámetros (IDOR).

---

## 2. Preparación del Entorno Local Limpio

### 2.1 Requisitos previos
- Elixir `1.15+` y Erlang/OTP `26+`.
- PostgreSQL `14+` en ejecución local con extensiones `btree_gist` habilitadas.
- Git.

### 2.2 Procedimiento de inicialización paso a paso

```bash
# 1. Posicionarse en la rama de integración
git checkout develop  # o la rama feature correspondiente

# 2. Instalar dependencias de Elixir
mix deps.get

# 3. Preparar la base de datos limpia (crea, migra y aplica extensiones GiST)
mix ecto.reset

# 4. Verificar compilación limpia y sin advertencias
mix compile --warnings-as-errors

# 5. Iniciar el servidor web Phoenix
mix phx.server
```

La aplicación quedará accesible en:
- **Aplicación web:** `http://localhost:4000`
- **Buzón local de correos (Magic Links y desafíos):** `http://localhost:4000/dev/mailbox`

---

## 3. Demostración Automatizada (Scripts Ejecutables y Tests)

Para una comprobación rápida, desatendida y forense, el repositorio incluye suites automatizadas y scripts reproducibles con salida sanitizada:

### 3.1 Script de Integración E2E del Recorrido Principal (#70)
Ejecuta de punta a punta: creación de profesional → configuración de consulta y agenda semanal → acceso por Magic Link de paciente → perfil e identidad → verificación telefónica → reserva autónoma → consulta y proyección en agenda profesional.

```bash
mix run priv/repo/check_prototype_journey_e2e.exs
```

*Resultado esperado:*
```text
================================================================================
 ORIGEN — ENSAYO E INTEGRACIÓN DEL RECORRIDO PRINCIPAL
 Subissue #70 (PLN-14) / Father Issue #47
 Objetivo: "Paciente reserva y Profesional lo ve"
================================================================================
▶ PASO 1: Profesional se autentica y configura sus servicios
   ✔ Cuenta profesional activa: dra.valenzuela@clinicaorigen.test (ID: ...)
   ✔ Sesión interna emitida: ID ...
   ✔ Tipo de consulta configurado: Consulta Médica Integral ($25000.00 ARS)
   ✔ Disponibilidad semanal configurada: Lunes a Viernes 08:00 a 16:00 hs
▶ PASO 2: Paciente accede, completa perfil y valida teléfono
   ✔ Magic Link emitido y consumido exitosamente para: lucas.rodriguez.demo@example.test
   ✔ Perfil completado: Lucas Rodríguez (DNI: 40123456)
   ✔ Desafío telefónico completado con código único (phone_verified: true)
▶ PASO 3: Paciente reserva turno autónomamente
   ✔ Reserva confirmada exitosamente: Turno #..., Estado: reserved, Duración: 30 min
▶ PASO 4: Profesional visualiza el turno en su agenda diaria
   ✔ Agenda consultada: 1 turno proyectado con datos no clínicos (Lucas Rodríguez, DNI 40123456)
▶ PASO 5: Verificación de barreras de seguridad, aislamiento y transaccionalidad
   ✔ Aislamiento horizontal verificado: Dr. Gómez no ve el turno de la Dra. Valenzuela.
   ✔ Barrera de teléfono verificado: Rechazada reserva para paciente sin verificar.
   ✔ Prevención de solapamiento: Rechazada reserva duplicada en el mismo slot.
================================================================================
```

### 3.2 Script de Regresión de Fallos y Reversión Transaccional (#71)
Ejecuta los escenarios de estrés: solicitudes concurrentes simultáneas por el mismo turno, usuarios anónimos, perfiles incompletos, colisiones de DNI derivadas a secretaría, fallos transaccionales inducidos (rollback atómico sin orfandad), inmunidad IDOR y sesiones revocadas.

```bash
mix run priv/repo/check_journey_failure_regression.exs
```

*Resultado esperado:*
```text
================================================================================
 ORIGEN — REGRESIÓN DE FALLOS Y REVERSIÓN TRANSACCIONAL DEL RECORRIDO
 Subissue #71 (PLN-14) / Father Issue #47
 Objetivo: "Horarios ocupados y accesos incorrectos"
================================================================================
▶ ESCENARIO 1: Solicitudes concurrentes simultáneas por el mismo turno
   ✔ Concurrencia resuelta deterministamente (1 ganador, 1 rechazado :slot_already_booked)
   ✔ Verificación forense en BD: Exactamente 1 turno registrado en el slot (OK)
▶ ESCENARIO 2: Barreras de identidad y perfil incompleto
   ✔ Usuario no autenticado: Rechazado con :unauthenticated
   ✔ Perfil en 'pending_completion': Rechazado con :patient_not_ready_for_booking
   ✔ Perfil 'completed' sin teléfono verificado: Rechazado con :patient_not_ready_for_booking
   ✔ Colisión de DNI: Derivado a secretaría y reserva bloqueada
▶ ESCENARIO 3: Reversión transaccional total (Rollback atómico)
   ✔ Rollback total ante fallo de relación: 0 turnos y 0 relaciones persistidas.
   ✔ Rollback total ante fallo de auditoría: 0 turnos y 0 relaciones persistidas.
   ✔ Integridad referencial forense: 0 turnos huérfanos y 0 relaciones huérfanas en el sistema.
▶ ESCENARIO 4: Confidencialidad médica y no exposición de datos ajenos
   ✔ Mensaje de conflicto opaco: No expone datos del titular del turno.
   ✔ Inmunidad contra IDOR: Parámetros del cliente ignorados; agenda filtrada por sesión.
   ✔ Sesión revocada: Acceso denegado inmediatamente con :unauthorized.
================================================================================
```

### 3.3 Ejecución de Suites de Pruebas de Integración
```bash
mix test test/origen/integration/
```
*Resultado esperado:* **17 tests pasando** (5 de recorrido principal + 12 de regresión de fallos).

---

## 4. Guion de Demostración en Vivo para Docentes (Paso a Paso Web)

Para realizar la presentación interactiva en el navegador ante los profesores:

| Paso | Acción en UI | URL | Datos de entrada (Ficticios) | Resultado visual esperado |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Acceso Paciente** | `http://localhost:4000/access` | Email: `carlos.docente@example.test` | Pantalla de confirmación "Revisá tu correo". |
| **2** | **Capturar Magic Link** | `http://localhost:4000/dev/mailbox` | Buscar correo a `carlos.docente@example.test` | Clic en el enlace de acceso (`/access/verify?token=...`). Sesión de paciente iniciada. |
| **3** | **Completar Perfil** | `http://localhost:4000/patient/profile/complete` | Nombre: `Carlos`, Apellido: `Pérez`, DNI: `35111222`, Nacimiento: `1989-10-10`, Tel: `+5491144556677` | Perfil guardado. Estado: `completed` (teléfono aún no verificado). |
| **4** | **Verificar Teléfono** | `http://localhost:4000/patient/phone/verify` | Clic en "Enviar código". Abrir `/dev/mailbox`, leer código de 6 dígitos e ingresar. | Badge verde "Teléfono verificado". Habilitado para reservar. |
| **5** | **Reservar Turno** | `http://localhost:4000/patient/calendar` | Elegir fecha hábil futura (>24h), seleccionar horario (ej. 10:00) y presionar "Confirmar Turno". | Tarjeta verde de confirmación con Turno ID, estado `reserved`, duración 30 min y precio en ARS. |
| **6** | **Visualizar en Agenda** | `http://localhost:4000/profesional/agenda` | Iniciar sesión como Profesional (previa creación de sesión o en IEx). | Agenda diaria muestra el turno en 10:00 - 10:30, paciente "Carlos Pérez", DNI 35111222 y badge "Reservado". |

---

## 5. Matriz de Controles Negativos Comprobados

| ID | Control Negativo | Mecanismo de Defensa | Resultado Observado |
| :--- | :--- | :--- | :--- |
| **CN-01** | **Doble reserva simultánea** (concurrencia en el mismo slot) | Restricción de exclusión PostgreSQL GiST (`tstzrange` no solapado) + validación previa en `Overlap`. | Transacción abortada limpiamente con error opaco `:slot_already_booked`. Solo 1 turno registrado. |
| **CN-02** | **Paciente sin teléfono verificado** (RF-02 ter) | `Patients.ready_for_booking?/1` evalúa `phone_verified: true`. | Rechazado con `:patient_not_ready_for_booking`. Botón deshabilitado en UI. 0 turnos en BD. |
| **CN-03** | **Perfil incompleto** (anónimo o `pending_completion`) | Validación fail-fast en `BookingService.reserve/2`. | Rechazado con `:unauthenticated` o `:patient_not_ready_for_booking`. |
| **CN-04** | **Colisión documental de DNI** (intento de usurpación) | Búsqueda `FOR UPDATE` en `personas`: si el DNI existe, deriva a secretaría (`pending_secretary_review`). | No se asocia Persona automáticamente, no se duplican registros y se bloquea la reserva. |
| **CN-05** | **Aislamiento horizontal entre profesionales** | Consulta en `Agenda.get_professional_agenda/2` filtrada exclusivamente por `owner_account_id` de la sesión. | Profesional B ve su agenda vacía para ese día. Nunca se listan turnos de otro profesional. |
| **CN-06** | **Manipulación de identificadores (IDOR)** | El backend ignora parámetros del cliente como `professional_id` o `account_id` en las consultas de agenda propia. | Se retorna siempre la agenda del actor autenticado en la sesión revalidada. |
| **CN-07** | **Acceso no autenticado o con roles ajenos** | Plug de sesión interna + `on_mount` en LiveView (`InternalAuthLive.ensure_professional`). | Rechazo con código HTTP 401 (no autenticado) o 403 (secretaría / administrador / paciente). |
| **CN-08** | **Fallo transaccional inducido** (rollback atómico) | Transacción única en PostgreSQL (`Booking.reserve_appointment/2`). | Rollback total: ante fallo en inserción de relación o auditoría, se eliminan turnos y relaciones huérfanas. |

---

## 6. Evidencia Sanitizada y Forense

### 6.1 Registro forense de un turno exitoso en PostgreSQL
```sql
SELECT id, patient_profile_id, professional_account_id, status, 
       start_time, end_time, snapshot_consultation_type_name, snapshot_exact_price_ars 
FROM appointments 
WHERE id = 3;
```
```text
 id | patient_profile_id | professional_account_id |  status  |       start_time        |        end_time         | snapshot_consultation_type_name | snapshot_exact_price_ars 
----+--------------------+-------------------------+----------+-------------------------+-------------------------+---------------------------------+--------------------------
  3 |                  8 |                      19 | reserved | 2026-09-28 10:00:00+00  | 2026-09-28 10:30:00+00  | Consulta Médica Integral        |                 25000.00
```

### 6.2 Comprobación de no orfandad relacional
```sql
-- Verificar que no existen turnos sin paciente ni profesional
SELECT count(*) FROM appointments WHERE patient_profile_id IS NULL OR professional_account_id IS NULL;
-- => 0

-- Verificar que no existen relaciones sin paciente ni profesional
SELECT count(*) FROM professional_patient_relationships WHERE patient_profile_id IS NULL OR professional_account_id IS NULL;
-- => 0
```

### 6.3 Comprobación de auditoría append-only
```sql
SELECT actor_kind, actor_ref, event, entity_kind, entity_ref, result 
FROM audit_events 
ORDER BY id DESC LIMIT 5;
```
```text
 actor_kind |        actor_ref        |                event                | entity_kind | entity_ref |  result   
------------+-------------------------+-------------------------------------+-------------+------------+-----------
 patient    | lucas.rodriguez@...     | phone_challenge_consumed            | patient     | lucas...   | succeeded
 patient    | lucas.rodriguez@...     | phone_challenge_issued              | patient     | lucas...   | succeeded
 patient    | lucas.rodriguez@...     | patient_profile_completed           | patient     | lucas...   | succeeded
 patient    | lucas.rodriguez@...     | magic_link_consumed                 | patient     | lucas...   | succeeded
 anonymous  | NULL                    | magic_link_issued                   | patient     | lucas...   | succeeded
```

---

## 7. Checklist para el Presentador durante la Demo

- [ ] Base de datos limpia e inicializada con `mix ecto.reset`.
- [ ] Servidor corriendo en puerto 4000 (`mix phx.server`).
- [ ] Pestañas del navegador abiertas:
  - `http://localhost:4000/access` (Acceso paciente).
  - `http://localhost:4000/dev/mailbox` (Buzón local de desarrollo).
  - `http://localhost:4000/profesional/agenda` (Agenda profesional).
- [ ] Terminal lista para ejecutar `mix test test/origen/integration/` y demostrar la suite automatizada.
- [ ] Destacar a los docentes:
  - La ausencia total de contraseñas para pacientes (Magic Link criptográfico).
  - El cumplimiento del requisito RF-02 ter de validación telefónica antes de reservar.
  - La inmutabilidad de los snapshots históricos de precio y duración.
  - La prevención matemática de solapamientos mediante restricciones GiST de PostgreSQL.

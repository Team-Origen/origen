# QA Manual — Subissue #93: Reserva Autónoma de Turnos (Father Issue #42)

> **Rama activa:** `feature/93-booking-calendar-submission`
> **PRs:** #172 (backend) y #174 (LiveView), CI 3/3 en verde.
> **Pre-requisito:** tener la app corriendo localmente con `iex.bat -S mix phx.server` en PowerShell.

---

## 0. Setup local

```powershell
# 1. Asegurate de estar en la rama correcta
git checkout feature/93-booking-calendar-submission

# 2. Correr migraciones (si no lo hiciste)
$env:MIX_ENV = "dev"
mix ecto.migrate

# 3. Levantar la app
iex.bat -S mix phx.server
```

Abri el navegador en `http://localhost:4000`.

---

## 1. Escenario A — Paciente sin telefono verificado NO puede reservar

### Pasos
1. Loguearse como paciente (o crear uno nuevo en `/patient/access`).
2. Completar el perfil **sin** verificar el telefono.
3. Navegar a `/patient/calendar`.
4. Elegir profesional, tipo de consulta, fecha y horario.
5. En el panel de confirmacion, presionar **"Confirmar Turno"**.

### Resultado esperado
- El boton debe aparecer grisado con el texto **"Verificacion de Telefono Requerida"**.
- Al presionar, aparece un flash con mensaje de error (sin crash).
- No se crea ningun turno en la base de datos.

---

## 2. Escenario B — Paciente verificado reserva exitosamente (RF-10 "reserved")

### Pasos
1. Loguearse como paciente con telefono verificado.
2. Navegar a `/patient/calendar`.
3. Seleccionar cualquier profesional y tipo de consulta.
4. Elegir una fecha **con mas de 24 horas de antelacion** (ej. 5 dias desde hoy).
5. Seleccionar un horario disponible.
6. Revisar el panel de confirmacion (politica de cancelacion visible).
7. Presionar **"Confirmar Turno"**.

### Resultado esperado
La tarjeta verde de exito debe mostrar:

| Campo | Ejemplo |
|---|---|
| Turno ID | `#12` (numero real de la DB) |
| Profesional | nombre del profesional seleccionado |
| Tipo de Consulta | nombre del tipo seleccionado |
| Fecha y Horario | `2026-09-28 de 10:00 a 10:30 hs` |
| Importe | `$18000.00` |
| Estado inicial (RF-10) | badge `reserved` |

### Verificacion adicional en IEx
```elixir
Origen.Repo.all(Origen.Booking.Appointment) |> Enum.map(& &1.status)
# => ["reserved"]
```

---

## 3. Escenario C — Turno en D o D-1 muestra estado "confirmed" (RF-10)

### Pasos
1. Mismo flujo que Escenario B.
2. Pero elegir la fecha de **hoy** o **manana**.

### Resultado esperado
- La tarjeta de exito muestra **Estado inicial (RF-10):** `confirmed`.

### Verificacion adicional en IEx
```elixir
Origen.Repo.all(Origen.Booking.Appointment) |> Enum.map(& &1.status)
# => ["confirmed"]
```

---

## 4. Escenario D — Cambio de tipo de consulta recalcula slots

### Pasos
1. Navegar a `/patient/calendar`.
2. Elegir "Consulta general" (30 min) → observar slots de 30 min.
3. Cambiar a "Procedimiento" (60 min) → slots deben regenerarse en pasos de 60 min.
4. Cambiar a "Control" (15 min) → slots deben regenerarse en pasos de 15 min.

### Resultado esperado
- La grilla de slots se actualiza dinamicamente sin recarga de pagina.
- Los slots respetan la duracion exacta del tipo de consulta seleccionado.

---

## 5. Escenario E — Script de verificacion de punta a punta

Desde la raiz del proyecto (en PowerShell o bash):

```powershell
mix run priv/repo/check_autonomous_booking_e2e.exs
```

### Resultado esperado
```
=== PRUEBA DE RESERVA AUTONOMA DE PUNTA A PUNTA (SUBISSUE #93) ===
1. Paciente autenticado y verificado: ana.gomez@example.test
   -> Telefono verificado: true
   -> ready_for_booking?: true
...
5. Resultado de la reserva:
   -> ID del Turno: #N
   -> Estado inicial (RF-10): reserved
   -> Tipo de Consulta (Snapshot): Consulta general
   -> Duracion: 30 min
   -> Precio exacto (ARS): $18000.00
...
6. Corroboracion forense en tabla 'appointments':
   -> Estado en BD: reserved
   -> Snapshot Nombre: Consulta general
   -> Snapshot Precio: $18000.00
=== PRUEBA DE RESERVA AUTONOMA COMPLETADA CON EXITO ===
```

---

## Checklist de cierre

| Criterio | Paso? |
|---|---|
| Paciente no verificado NO puede reservar | [ ] |
| Paciente verificado confirma turno exitosamente | [ ] |
| Tarjeta muestra ID real, precio y estado RF-10 | [ ] |
| Estado `reserved` para citas > 24 hs | [ ] |
| Estado `confirmed` para citas en D-1 / D | [ ] |
| Recalculo de slots por tipo de consulta | [ ] |
| Script E2E pasa sin errores | [ ] |
| Sin crashes en logs de la app | [ ] |

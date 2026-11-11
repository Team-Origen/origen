# Handoff — backend del resumen económico (#389)

## Resultado primero

**Entrega parcial para continuidad, no verificada de forma independiente, no completa y no lista para merge.** La rama que contiene todo el código y este handoff es `feat/389-02-summary`, basada en `develop` `7372371`. Los commits de implementación son `aecb97fe8d0262ffe66123ad7bd1e7cbc6fe048a` (períodos) y `632a1290ac87b49a9671715a1251fa409939f367` (consulta autorizada y agregación). La publicación de esta entrega no implica PR, merge, cierre de issues ni aprobación del backend.

Cadena local para revisión: `feat/389-economic-summary` (base `7372371`) → `feat/389-01-periods` (`aecb97f`, 367 líneas añadidas) → `feat/389-02-summary` (`632a129` más este handoff). La segunda unidad tiene 661 líneas añadidas/eliminadas, incluidas sus pruebas y documentación: se mantiene coherente en lugar de separar la autorización y el cálculo de las pruebas que los respaldan.

Alcance y trazabilidad: [#389](https://github.com/Team-Origen/origen/issues/389), padre [#288](https://github.com/Team-Origen/origen/issues/288), contrato [#388](https://github.com/Team-Origen/origen/issues/388), y [OpenSpec `health-center-beta-core`](../../../openspec/changes/health-center-beta-core/) con scope backend #389. La integración #391 no pertenece a este backend; el mock frontend de [#390](https://github.com/Team-Origen/origen/issues/390) queda intacto.

## Para continuar

1. Obtener las ramas remotas y hacer checkout de `feat/389-02-summary`; incluye los dos commits de implementación y este handoff, sin depender de cambios locales sin commit.
2. Leer primero el [contrato #388](../contracts/388-resumen-economico-por-fecha-turno.md) y el [contrato técnico de la operación](../../booking/ECONOMIC_SUMMARY.md).
3. Resolver el runner con PostgreSQL descartable y runtime aislado; no usar la base por defecto ni mutar el toolchain global.
4. Ejecutar la checklist pendiente de abajo. Los resultados históricos del escritor no sustituyen la verificación independiente ni la revisión final del parent.

## Qué quedó implementado

La API pública es `Origen.Booking.economic_summary(principal, professional_id, period_params)` y devuelve `{:ok, %{professional, period, paid, pending, total}}`. Los tres importes son `Decimal` exactos en ARS y `total = paid + pending`. El período acepta mes calendario (`YYYY-MM`) o rango inclusivo (`from`/`to`); fechas iguales representan un día completo. Los límites son semiabiertos en UTC, derivados de `organization_timezone`.

La consulta filtra por la fecha del turno (`start_time`), no por `paid_at`, corrección o fecha de consulta, y usa el precio final vigente del turno (`final_price_ars`). Marca pagada: suma a `paid` cualquier estado operativo con pago vigente, conservando pagos de cancelados y ausencias. Marca pendiente: sólo suma turnos `confirmed` o `attended`; impagos de `cancelled`, `no_show`, `requested`, `reserved` y `expired` quedan fuera. Pagos tardíos, reversas, cambios de precio y precio cero siguen esas reglas sin duplicar historia.

La autorización revalida la sesión en cada invocación y aplica default-deny: un Profesional sólo puede consultar su propio resumen; Secretaría consulta un Profesional activo por vez; Administrador, Paciente, anónimo, sesiones inválidas/revocadas, cuentas inactivas, identificadores ajenos o selecciones inválidas no reciben importes. La operación es sólo lectura y delega desde `Booking`.

## Mapa de código, pruebas y documentación

| Área | Archivos |
| --- | --- |
| API y agregación | [`lib/origen/booking.ex`](../../../lib/origen/booking.ex), [`lib/origen/booking/economic_summary.ex`](../../../lib/origen/booking/economic_summary.ex) |
| Períodos y límites locales/UTC | [`lib/origen/booking/economic_summary_period.ex`](../../../lib/origen/booking/economic_summary_period.ex) |
| Matriz de autorización | [`lib/origen/authorization/rules.ex`](../../../lib/origen/authorization/rules.ex), [`docs/security/AUTHORIZATION_MATRIX.md`](../../security/AUTHORIZATION_MATRIX.md) |
| Pruebas del período | [`test/origen/booking/economic_summary_period_test.exs`](../../../test/origen/booking/economic_summary_period_test.exs) |
| Pruebas de resumen, pagos, permisos y sólo lectura | [`test/origen/booking/economic_summary_test.exs`](../../../test/origen/booking/economic_summary_test.exs), [`test/origen/booking/authorization_test.exs`](../../../test/origen/booking/authorization_test.exs) |
| Contrato de la operación | [`docs/booking/ECONOMIC_SUMMARY.md`](../../booking/ECONOMIC_SUMMARY.md) |

## Evidencia histórica y límites

La evidencia del escritor fue: T1 RED con 7 fallos, exit 2, luego 8/8 pasadas; T2 RED con 12 fallos, luego focused 51 pasadas; pagos 35 pasadas y 3 omitidas; suite completa 1179 pasadas, 35 omitidas y 8 excluidas; formatter y `git diff --check` pasaron. Es evidencia histórica de quien escribió los cambios, no una certificación final.

Todas las sondas independientes intentadas hasta ahora ejecutaron cero tests, formatter o probes: no reprodujeron ningún bug de código. En los intentos de setup, las rutas exactas del PostgreSQL 18.6 del parent funcionaron; un wrapper con rutas absolutas a Mix/Elixir 1.20.3 sobre Erlang 28.0 superó el problema de `HOME`/`PATH`, pero `mix ecto.migrate` quedó bloqueado por la incompatibilidad de `Hex.Netrc.Cache` de Hex 2.5.1 (BEAM/op `make_fun2` con OTP). Hace falta un Hex/runtime compatible en un entorno aislado; no depender de rutas de una máquina, scratch local, base por defecto ni cambios globales del toolchain.

Los casos que aún no tienen prueba independiente son pendientes, no fallos establecidos. La entrega tampoco declara completa la cobertura R1–R18, aunque el código y las pruebas propias cubren una parte sustancial del contrato.

## Checklist restante

- [ ] Resolver el toolchain de pruebas en una base PostgreSQL descartable, siguiendo la configuración existente y usando `ORIGEN_DATABASE_URL` explícito; no hardcodear la base por defecto.
- [ ] Ejecutar el focused exacto: `mix test test/origen/booking/economic_summary_period_test.exs test/origen/booking/economic_summary_test.exs test/origen/booking/authorization_test.exs`.
- [ ] Ejecutar la ruta de pagos: `mix test test/origen/booking/*payment*.exs`.
- [ ] Ejecutar `mix test` completo después del focused y de cualquier corrección autorizada.
- [ ] Realizar una verificación independiente real de R1–R18: Buenos Aires, `00:30 UTC` del 1 de diciembre que pertenece al 30 de noviembre; pago genuinamente en diciembre para un turno de noviembre; reversa/cancelación/no-show actuales; roles y sesiones forjadas, revocadas, vencidas e inactivas; Secretaría con selección inválida, global, inactiva y enorme; proyecciones públicas de sólo lectura; y la invariante de cobertura de joins.
- [ ] El parent debe hacer su spot-check, repetir el check final y la suite completa; la finalización del reviewer es una etapa separada.

Cualquier nuevo intento de reparación o verificación requiere autorización humana explícita y debe ser acotado al setup compatible y a los checks anteriores; no implica reintentos ilimitados. Hasta entonces, tratar esta rama como entrega funcional parcial para que otro compañero termine y valide el backend.

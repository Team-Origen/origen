# Decisión y Especificación de Seguridad: Desafíos Telefónicos (PLN-15 / Issue #88)

## 1. Contexto y Problema

Para la autogestión y reserva autónoma del Paciente (`RF-02 ter`, `RF-05`, `RF-17`, `BOOK-01`), el sistema requiere que el perfil cuente con un teléfono verificado (`phone_verified: true`), dado que los recordatorios de citas se envían por WhatsApp en D-2 y D-1.

En entornos locales de desarrollo (`:dev`) y de pruebas automatizadas (`:test`):
- No se dispone de cuentas ni contratos activos de proveedores de SMS o WhatsApp (Twilio, Meta WhatsApp Cloud API, Gupshup, etc.).
- Está terminantemente prohibido almacenar credenciales de servicios pagos o reales en repositorios o máquinas locales de desarrollo.
- Se debe garantizar la privacidad y el aislamiento local sin incurrir en costos operativos ni envío de mensajes a personas reales.

## 2. Decisión Arquitectónica

Se adopta formalmente la entrega de desafíos telefónicos no productivos mediante el **buzón local de Swoosh** (`Swoosh.Adapters.Local`, visible en `/dev/mailbox`), reutilizando la dirección de correo electrónico del Paciente autenticado previamente en `/access`:

1. El Paciente registra o actualiza su número de teléfono en su perfil de paciente.
2. Al solicitar la verificación, el sistema genera un desafío criptográfico y despacha un correo de notificación local a la casilla del Paciente con el código numérico de 6 dígitos.
3. El desarrollador o tester inspecciona el buzón local (`http://localhost:4000/dev/mailbox`), extrae el código e ingresa el valor en la pantalla de verificación.
4. Tras la validación exitosa, el sistema marca el teléfono como verificado sin haber consumido ningún servicio externo ni expuesto credenciales.

## 3. Especificación del Desafío de Seguridad

| Parámetro | Valor | Justificación / Regla |
| :--- | :--- | :--- |
| **Formato del código** | 6 dígitos numéricos (`100000..999999`) | Generado con `:crypto.rand_uniform/2`. Prohibidos códigos fijos o previsibles. |
| **Protección en reposo** | Hash SHA-256 (`code_hash`) | **NUNCA** se almacena el código en texto plano en la base de datos. |
| **Comparación de código** | Tiempo constante (`Plug.Crypto.secure_compare/2`) | Mitiga ataques de temporización (timing attacks). |
| **Caducidad (TTL)** | 10 minutos (600 segundos) | Ventana acotada de validez. Expirado el plazo, el desafío queda invalidado. |
| **Límite de intentos** | Máximo 3 intentos fallidos | Al 3er fallo, el desafío transiciona a `max_attempts_exceeded` y se bloquea. |
| **Un solo uso** | Atómico (`pending` -> `consumed`) | Un código válido verifica una sola vez; no admite reusabilidad. |
| **Frecuencia de reenvío** | Cooldown de 60 segundos | Previene saturación y ataques de denegación de servicio. |
| **Cuota por hora** | Máximo 5 solicitudes por hora | Límite por cuenta/teléfono para evitar abuso. |

## 4. Reglas de Privacidad, Logs y Auditoría

1. **Prohibición de secretos en sumideros:** El código en texto plano jamás debe registrarse en logs de aplicación, trazas de errores, cabeceras ni eventos de auditoría (`audit_events`).
2. **Enmascaramiento de teléfonos:** En cualquier registro de log o metadato de auditoría, el número telefónico debe enmascararse obligatoriamente (ejemplo: `+54...5566`), conservando solo prefijo y los últimos 4 dígitos visibles.
3. **Eventos auditables:** Se auditan la emisión del desafío, cada intento fallido y la verificación exitosa bajo la tabla `audit_events`, con resultado tipado (`'succeeded'`, `'failed'`).

## 5. Candado de Configuraciones Productivas (Fail-Closed)

En estricta consonancia con `Origen.BootstrapAdmin.DeliveryConfig`:
- Los adaptadores de mensajería productivos permanecen cerrados y deshabilitados hasta que exista autorización contractual y de seguridad explícita.
- En entornos `:dev` y `:test`, cualquier intento de configurar un canal externo o proveedor real es rechazado de forma cerrada (`:production_channel_unauthorized` / `:invalid_channel_config`).
- El canal `:local_mailbox` es el único autorizado para entornos de desarrollo y pruebas.

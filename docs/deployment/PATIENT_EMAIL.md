# Correo real de acceso para pacientes — #490

La integración utiliza Resend por HTTPS mediante `Origen.PatientAccess.Mailer` y Swoosh. Está preparada para la primera entrega académica; configurar el adaptador **no demuestra recepción real**. La aceptación requiere la prueba autorizada de este documento y un entorno HTTPS operativo coordinado con #292.

## Estado del respaldo de trabajo — #490

Este avance queda pausado en una rama de trabajo: no es una entrega aprobada ni autoriza su despliegue. El código de Origen todavía utiliza la integración Resend descrita aquí; Gmail API no está integrado en la aplicación.

- Verificación observada: 64 pruebas focalizadas aprobadas; suite en base nueva aislada con 1.206 aprobadas, 35 omitidas y 8 excluidas. La base habitual contenía datos persistentes que explicaban los 102 fallos de la ejecución anterior. La revisión independiente no pudo ejecutarse.
- Preparación externa de Gmail: proyecto `origen-turnera-correo-18250f`, API habilitada, consentimiento de envío y renovación OAuth comprobados. Google aceptó un único correo técnico autorizado; recepción en la casilla no confirmada. No se probó un magic link real ni el recorrido desde Render.
- Las credenciales y herramientas locales de autorización permanecen fuera del repositorio y no forman parte del respaldo de GitHub. No copiar secretos ni tokens a esta rama. OAuth en modo Testing conserva la limitación de vencimiento del refresh token a los siete días.
- Para retomar: decidir la integración Gmail, implementar y probar su renovación y manejo de errores, obtener revisión independiente y completar la aceptación autorizada en Render. Volver a `develop` no incorpora estos avances ni revoca la configuración externa de Google.

## Preparar el entorno

1. Registrar aprobación de proveedor/plan, responsable de la cuenta, dominio, remitente y casilla de prueba. Resend es la opción de esta integración, no una autorización para contratar ni gastar. Confirmar cuotas vigentes en [precios](https://resend.com/pricing); el plan gratuito consultado permite 3.000 mensajes mensuales y 100 diarios.
2. Verificar un dominio propio o subdominio de envío en Resend. Su responsable aplica los registros SPF y DKIM indicados por el proveedor y acuerda DMARC. No duplicar registros SPF ni aplicar una política de rechazo sin revisar otros emisores. El hostname gratuito `onrender.com` sirve como destino del enlace, no como dominio propio de correo.
3. Crear una API key restringida a envío y al dominio necesario. Entregarla por el canal de secretos autorizado, nunca por GitHub, chat ni Git. Restringir también el acceso al panel del proveedor: puede mostrar mensajes con credenciales temporales. Mantener desactivados el seguimiento de aperturas y clics del dominio transaccional.
4. Cargar las variables siguientes mediante secretos/configuración de runtime en Render. El Blueprint contiene campos sin valores; no desplegar esta revisión sin completarlos. La validación también se ejecuta en comandos de release que cargan runtime, incluidas migraciones.
5. Desplegar solo con autorización. No habilitar `dev_routes` ni publicar `/dev/mailbox` para resolver problemas de entrega.

| Variable | Uso |
| --- | --- |
| `RESEND_API_KEY` | Secreto de envío del proveedor. Obligatorio en `:prod`; no se guarda en el repositorio. |
| `ORIGEN_PATIENT_EMAIL_FROM` | Dirección simple del remitente verificado, sin nombre ni `<...>`. Obligatoria en `:prod`. |
| `PHX_HOST` | Host público aprobado, sin esquema, puerto ni ruta. Tiene prioridad sobre `RENDER_EXTERNAL_HOSTNAME`. |
| `RENDER_EXTERNAL_HOSTNAME` | Alternativa provista por Render si no se define `PHX_HOST`. |

El endpoint genera el origen HTTPS de los enlaces en producción. No se usa el host recibido del solicitante. Credenciales vacías, remitentes de ejemplo y hosts locales/de ejemplo impiden arrancar con configuración incompleta. La validación sintáctica no prueba propiedad del dominio, aprobación ni verificación en Resend.

## Comportamiento y límites

- Solo los magic links usan el nuevo mailer. `Origen.Mailer`, los códigos de verificación telefónica, las invitaciones de personal y el bootstrap no se habilitan para envío real por este cambio.
- Desarrollo conserva Swoosh Local y MailBox; tests usan Swoosh Test sin conexiones reales al proveedor.
- Primero se confirma la emisión y auditoría del enlace en base de datos; después se contacta al proveedor, fuera de la transacción. Un fallo de auditoría/persistencia no debe enviar mensajes.
- Se conservan hash del token, vencimiento de 15 minutos, uso único e invalidación de enlaces anteriores. Un fallo de envío no revierte esa emisión ni restaura enlaces anteriores. El paciente puede solicitar otro enlace, que invalida el anterior.
- Hay un intento, sin reintentos automáticos: conexión y lectura tienen timeouts de 5 segundos cada una; no es un límite total garantizado de 5 segundos. Un timeout puede ocurrir después de que el proveedor aceptó el mensaje.
- No hay cola durable: una caída entre commit y envío puede perder el envío. La recuperación automática y los webhooks quedan fuera de esta primera entrega.
- La respuesta pública sigue siendo opaca; `{:ok, :delivered}` es compatibilidad del contrato existente, no confirmación de recepción. No se garantiza igualdad de tiempos de respuesta entre cuentas conocidas y desconocidas.

## Diagnóstico sin exponer datos

| Evento operativo | Significado / acción |
| --- | --- |
| `patient_magic_link_issuance_failed` | Falló la preparación/persistencia/auditoría. Revisar salud de base y auditoría sin habilitar logs sensibles. |
| `patient_magic_link_delivery_failed` | Rechazo, timeout o excepción de entrega. Revisar credencial, dominio verificado, cuotas y estado del proveedor en un panel de acceso restringido. No asumir que un timeout implica rechazo. |
| `patient_magic_link_provider_accepted` | El adaptador aceptó el mensaje; no acredita llegada a la bandeja de entrada. |

No registrar respuestas crudas del proveedor, cuerpos, destinatarios, tokens, enlaces completos ni credenciales. Mantener filtros de logs/APM también en proxy y plataforma. Ante credencial comprometida, revocarla, reemplazar el secreto y reiniciar con autorización; nunca copiarla a evidencia. Si cambia el dominio público, coordinar el cambio: correos ya emitidos conservan el destino anterior.

## Aceptación real pendiente

Con autorización específica y usando paciente ficticio y casilla controlada:

- [ ] Registrar versión, entorno, fecha y operador; proveedor/plan, responsable, remitente verificado y origen HTTPS aprobado, sin secretos.
- [ ] Solicitar acceso desde la aplicación y comprobar recepción real, incluyendo spam.
- [ ] Comprobar que el enlace apunta al origen HTTPS esperado y completa el acceso del paciente ficticio.
- [ ] Comprobar uso único, vencimiento e invalidación con solicitudes posteriores.
- [ ] Comprobar que `/dev/mailbox` no está expuesto y que la evidencia/logs no contienen credenciales temporales ni datos personales reales.
- [ ] Adjuntar resultado sanitizado y limitaciones a #490. Marcar bloqueado lo no observado; no declarar recepción basándose en un test o en aceptación de la API.

Pruebas locales: `mix test test/origen/patient_email_config_test.exs test/origen/patient_email_delivery_test.exs test/origen/patient_access_test.exs`. No enviar correo real desde la suite.

Referencias: [despliegue Render](RENDER.md), [aceptación académica](ACEPTACION_HOSTING_ACADEMICO.md), [dominios Resend](https://resend.com/docs/dashboard/domains/introduction), [tracking](https://resend.com/docs/dashboard/domains/tracking), [limitaciones Render Free](https://render.com/docs/free).

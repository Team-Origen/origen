# Accesos conectados e invitación de cuentas (#473)

Las pantallas existentes conservan sus formularios, URLs y mecanismos de autenticación. Los enlaces secundarios usan navegación normal y no envían formularios ni cierran sesiones.

| Pantalla | Enlace secundario | Destino |
| --- | --- | --- |
| `/` (con o sin sesión de paciente) | Acceso del personal | `/login` |
| `/paciente/acceso` (formulario y confirmación) | Acceso del personal | `/login` |
| `/login` | Acceder como paciente | `/paciente/acceso` |

## Invitación al crear una cuenta

1. Como Administrador activo, abrir `/administrador/cuentas` y crear la cuenta profesional.
2. El resultado muestra el enlace de la invitación ya generada: **Copiar enlace** lo copia localmente y **Abrir invitación** lo abre en otra pestaña.
3. Si el navegador deniega el portapapeles, el campo queda seleccionado para copiarlo manualmente. No se genera otra invitación al copiar o abrir.

El mecanismo existente `Accounts.create_and_invite_internal_account/3` crea la cuenta y su invitación en una transacción. Devuelve el token crudo una sola vez; la persistencia guarda su verificador. La presentación anterior mostraba ID y token, pero no un enlace utilizable. Este cambio reutiliza ese retorno, sin agregar generación, reenvío ni entrega por MailBox.

El enlace usa el origen configurado del Endpoint y `/activar`, con las credenciales en el fragmento, compatible con el intercambio existente de activación. La apertura usa `noopener noreferrer`. La pantalla mantiene su autorización exclusiva para Administrador activo; el enlace sólo vive en el resultado de creación y desaparece al recargar. No se cambian caducidad, uso único ni validaciones de activación.

**El enlace es una credencial:** compartirlo sólo con la persona invitada. No incluirlo en capturas, logs, issues o evidencia. Usar cuentas ficticias y ocultar todo el enlace en cualquier evidencia visual. MailBox sigue siendo una herramienta de desarrollo, no un mecanismo nuevo de entrega de estas invitaciones.

## Revisión visual y navbar

La aprobación visual final y la comprobación de navbar corresponden al usuario. El usuario comunicó su aprobación final de todo el alcance después de solicitar y revisar el ajuste del texto negro en el campo de invitación. No se presentan como realizadas por las pruebas automatizadas.

- En escritorio y móvil, recorrer los tres enlaces con Tab y Enter; comprobar legibilidad, foco visible y destino.
- Comprobar el portal con y sin sesión de paciente y confirmar que navegar no cierra sesiones ni solicita correos.
- En cuentas, comprobar copiar, rechazo del portapapeles y apertura en otra pestaña usando una cuenta ficticia; ocultar la credencial en las capturas.
- Recorrer las entradas y acciones de cada navbar con sus roles existentes. Registrar cualquier destino o acción sin funcionalidad; no implementar funciones ajenas a #473.

El componente compartido `role_navigation.ex` contiene un aviso «Próximo en implementar» para entradas sin destino. El logo no es un enlace. Esto no constituye una auditoría funcional de todas las navbars ni autoriza cambiar sus funciones.

## Pruebas automatizadas

```sh
MIX_TEST_PARTITION=_issue473 mix test test/origen_web/controllers/page_controller_test.exs test/origen_web/live/patient_access_live_test.exs test/origen_web/controllers/internal_session_controller_test.exs
MIX_TEST_PARTITION=_issue473 mix test test/origen_web/live/admin_internal_live_test.exs test/origen_web/live/internal_accounts_integration_test.exs test/origen_web/controllers/internal_activation_controller_test.exs
```

La partición evita usar la base de pruebas predeterminada. Resultados observados:

- Pruebas enfocadas: 20 aprobadas para accesos y 55 para cuentas/activación. Verificación independiente combinada: 75 aprobadas.
- Verificador independiente: sin bloqueos de seguridad causados por el cambio; comprobaciones adicionales de generación única, permisos y portapapeles mediante un entorno simulado aprobadas.
- `git diff --check` y formato de los archivos Elixir modificados: salida 0.
- Suite completa: 1118 aprobadas, 1 fallida, 32 omitidas y 8 excluidas; salida 2. Falló `POST /login authenticates an activated account and renews the browser session`, con 422 en lugar de 302. Las pruebas enfocadas actuales y de la base pasan; no se confirmó que sea un fallo preexistente ni se considera la suite completa aprobada. El verificador identificó como hipótesis un cruce de ventana temporal TOTP, no una causa demostrada.
- La evaluación nativa de riesgo no estuvo disponible (`package-local-binary-missing`); se realizó verificación independiente por tratarse de una credencial sensible. El modo de revisión nativa estaba desactivado y no se inició una revisión.

No hubo verificación automatizada en navegador: Tidewave informó que no había un navegador conectado. No se adjuntaron capturas ni credenciales. El usuario otorgó la aprobación visual y de navbar y solicitó publicar el PR y cerrar la issue; el fallo observado de la suite completa se conserva documentado, sin presentarlo como resuelto.

# Invitación local de profesional y secretaria

Esta guía permite que cada desarrollador cree y active cuentas locales de `professional` y `secretary` usando su administrador local ya activo.

> **Windows:** ejecutá los comandos dentro de **WSL2**, con el repositorio clonado en tu home de Linux (por ejemplo `~/origen`), no en `/mnt/c/`. Podés abrir los enlaces en Chrome o Edge de Windows.

## Antes de empezar

- Estás en tu propia base de datos local.
- Ya tenés un administrador con estado `active`.
- `config/dev.local.exs` existe, está ignorado por Git y contiene:

  ```elixir
  config :origen,
    bootstrap_admin_verifier_key: "una-clave-local-de-al-menos-32-bytes",
    totp_keyring: %{
      active: %{tag: "dev.v1", key: "otra-clave-local-de-32-bytes"},
      retired: []
    }
  ```

- Para la prueba local por HTTP, agregá también:

  ```elixir
  config :origen, allow_insecure_http_activation: true
  ```

  Después de cambiar `config/dev.local.exs`, reiniciá `mix phx.server`. Esto es exclusivamente local. No lo copies a configuración compartida, staging ni producción.

## 1. Iniciar la aplicación

En una terminal, desde el repositorio:

```bash
mix phx.server
```

Dejala abierta.

## 2. Crear las dos invitaciones

En **otra** terminal, desde el repositorio:

```bash
iex -S mix
```

Pegá este bloque y reemplazá ambos emails por los que quieras usar localmente:

```elixir
import Ecto.Query

admin_id =
  Origen.Repo.one!(
    from a in "internal_accounts",
      where: a.role == "administrator" and a.state == "active",
      select: a.id,
      limit: 1
  )

verifier_key = Application.fetch_env!(:origen, :bootstrap_admin_verifier_key)

{:ok, professional} =
  Origen.Accounts.create_and_invite_internal_account(
    admin_id,
    %{email: "profesional@clinicaorigen.local", role: :professional},
    verifier_key: verifier_key
  )

{:ok, secretary} =
  Origen.Accounts.create_and_invite_internal_account(
    admin_id,
    %{email: "secretaria@clinicaorigen.local", role: :secretary},
    verifier_key: verifier_key
  )
```

## 3. Abrir los enlaces de activación

En la misma consola, ejecutá:

```elixir
"http://localhost:4000/activate#invitation_id=#{professional.invitation_id}&token=#{professional.token}"

"http://localhost:4000/activate#invitation_id=#{secretary.invitation_id}&token=#{secretary.token}"
```

Abrí la **URL completa** que imprime cada expresión, incluyendo `#invitation_id=...&token=...`. Abrir solamente `http://localhost:4000/activate` no alcanza y mostrará `Activation unavailable`, porque no identifica ninguna invitación.

No publiques, subas ni pegues estos enlaces en tickets, PRs o chats: contienen un token de invitación.

## 4. Activar cada cuenta

Para cada enlace:

1. Escaneá el QR con Google Authenticator, 1Password o una app TOTP equivalente.
2. Elegí una contraseña de al menos 12 caracteres y confirmala.
3. Ingresá el código actual de 6 dígitos de la app.
4. Seleccioná **Activar cuenta**.

La activación redirige a `/login`.

## 5. Iniciar sesión

En `/login`, ingresá:

- **Email o ID de cuenta:** el email usado al crear la invitación.
- **Contraseña:** la definida durante la activación.
- **Código del autenticador:** los 6 dígitos actuales de la app TOTP.

## Si la invitación no funciona

Una invitación vence a las 24 horas y se usa una sola vez. Si todavía está pendiente, el administrador puede reemplazarla. En IEx:

```elixir
{:ok, replacement} =
  Origen.Accounts.reissue_internal_invitation(
    admin_id,
    professional.account_id,
    verifier_key: verifier_key
  )

"http://localhost:4000/activate#invitation_id=#{replacement.invitation_id}&token=#{replacement.token}"
```

La invitación anterior queda invalidada automáticamente.

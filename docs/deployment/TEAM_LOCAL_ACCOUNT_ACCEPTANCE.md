# Procedimiento y aceptación local de primer Administrador — Origen

Este documento establece el procedimiento operativo para la aceptación real del primer Administrador local en estaciones de trabajo aisladas de desarrollo (`:dev`), conforme a la issue #51 y el cambio OpenSpec `team-local-account-acceptance`.

Cada participante ejecuta el recorrido personalmente en su computadora sobre una base PostgreSQL local independiente y sobre la revisión común acordada. No se permite compartir secretos, credenciales, tokens, enlaces, contraseñas, TOTP, contenido del mailbox ni filas de base de datos.

> **Importante para usuarios de Windows (WSL2 obligatorio):**
> 
> Si estás en Windows, debés ejecutar todo este proceso dentro de **WSL2 (Ubuntu)**.
> - **El proyecto debe estar clonado dentro de Ubuntu** (en `~/Documents`, que es `/home/usuario/Documents`), **NUNCA dentro de `/mnt/c/`** (el disco de Windows no soporta los permisos Unix estrictos que valida la aplicación).
> - Podés abrir y editar los archivos cómodamente con VS Code ejecutando `code .` dentro de la terminal de Ubuntu.
> - Podés usar tu navegador normal de Windows (Chrome, Edge, etc.) para entrar a `https://127.0.0.1:4001/dev/mailbox`, ya que Windows enlaza automáticamente los puertos de WSL2.
> - Herramientas necesarias en Ubuntu: `sudo apt update && sudo apt install -y libnss3-tools openssl mkcert` (si `mkcert` no está en los repositorios de tu versión de Ubuntu: `sudo apt install -y libnss3-tools && curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64" && chmod +x mkcert-v*-linux-amd64 && sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert`).

## 1. Revisión común de aceptación

- **Rama base:** `fix/local-bootstrap-config-lifecycle`
- **SHA común:** `a90e2132e7b3bcb9d0d6dd9588f3537dc965b353`

```bash
git fetch origin fix/local-bootstrap-config-lifecycle
git switch --detach a90e2132e7b3bcb9d0d6dd9588f3537dc965b353
git rev-parse HEAD
# Debe imprimir exactamente: a90e2132e7b3bcb9d0d6dd9588f3537dc965b353
```

## 2. Preparación de claves y certificado privados

```bash
SECRET_DIR="$HOME/.config/origen/bootstrap"
umask 077
mkdir -p "$SECRET_DIR"
openssl rand -base64 32 > "$SECRET_DIR/verifier.key"
openssl rand -base64 32 > "$SECRET_DIR/totp.key"
mkcert -install
mkcert -cert-file "$SECRET_DIR/localhost.pem" -key-file "$SECRET_DIR/localhost-key.pem" 127.0.0.1
chmod 700 "$SECRET_DIR"
chmod 600 "$SECRET_DIR"/*
```

Si falta `mkcert` en macOS: `brew install mkcert`.

## 3. Configuración local

Copiar la plantilla a `config/dev.local.exs` y configurar con permisos restrictivos (`chmod 600 config/dev.local.exs`):

```bash
cp config/dev.local.example.exs config/dev.local.exs
chmod 600 config/dev.local.exs
```

Completar los siguientes campos:

- Credenciales PostgreSQL locales y base aislada (ej. `origen_<nombre>`).
- Destino sintético propio en minúsculas (ej. `<nombre>@example.test`).
- Puerto HTTPS `4001` (número entero, sin comillas).
- Rutas absolutas a los 4 archivos creados en el paso 2.
- `retention_ttl_seconds: 900` y `max_messages: 1` (números enteros, sin comillas).
- `totp_key_tag: "local_dev_v1"`.
- El mismo nombre de base en Repo y en `database_name`.
- Ambas compuertas locales (`bootstrap_admin_local_enabled` y `bootstrap_admin_local.enabled`) inicialmente en `false`.

Verificar que el archivo esté ignorado por git:
```bash
git check-ignore config/dev.local.exs
```

## 4. Base de datos aislada

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
```

No usar ninguna base, cuenta, destino o credencial de staging ni producción.

## 5. Recorrido de emisión y activación

1. Activar las dos compuertas locales a `true` en `config/dev.local.exs`:
   ```elixir
   bootstrap_admin_local_enabled: true
   enabled: true # dentro de bootstrap_admin_local
   ```
2. Iniciar el comando:
   ```bash
   ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true mix origen.bootstrap_admin
   ```
3. Mantener la terminal abierta (está ejecutando el servidor HTTPS y esperando la activación).
4. En el navegador, abrir el buzón local:
   ```text
   https://127.0.0.1:4001/dev/mailbox
   ```
5. Abrir el único mensaje, hacer clic derecho en el enlace de activación y seleccionar **Abrir en una pestaña nueva** (para evitar quedar dentro del marco del buzón).
6. Copiar el `secret=` de la pantalla y generar el código TOTP en otra terminal:
   ```bash
   mix run -e 'IO.puts(NimbleTOTP.verification_code(Base.decode32!("PEGAR_SECRET_ACA", padding: false)))'
   ```
7. Completar la contraseña (mínimo 12 caracteres), confirmación y el código TOTP de 6 dígitos.
8. Enviar el formulario. Confirmar redirección a `/` y que el comando en la terminal finalizó con éxito.

## 6. Desactivación y verificación de limpieza

Volver a colocar en `false` las compuertas locales en `config/dev.local.exs`.
Verificar que la ejecución posterior falle cerrada:
```bash
ORIGEN_BOOTSTRAP_ADMIN_ENABLED=true mix origen.bootstrap_admin
# Debe responder: ** (Mix) Bootstrap admin request was rejected
```

## 7. Registro de constancias sanitizadas

Las cuatro constancias deben pertenecer a la misma revisión común (`a90e2132e7b3bcb9d0d6dd9588f3537dc965b353`) y ser completadas de manera personal e independiente por cada participante.

| Participante | SHA | Recorrido completo | Un Administrador y cero adicionales | Consumo único y limpieza | Finalización UTC | Confirmación personal | Motivo | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Lucca Giordana | `a90e2132e7b3bcb9d0d6dd9588f3537dc965b353` | pass | pass | pass | 2026-09-15 00:13:00Z | confirmed | none | ✅ pass |
| Santiago Casali | `a90e2132e7b3bcb9d0d6dd9588f3537dc965b353` | pending | pending | pending | — | pending | none | ⏳ pendiente |
| Said Quioto | `a90e2132e7b3bcb9d0d6dd9588f3537dc965b353` | pending | pending | pending | — | pending | none | ⏳ pendiente |
| Samuel Olmos | `a90e2132e7b3bcb9d0d6dd9588f3537dc965b353` | pending | pending | pending | — | pending | none | ⏳ pendiente |

### Detalle de constancias textuales

#### 1. Lucca Giordana
```text
Participante: Lucca Giordana
SHA: a90e2132e7b3bcb9d0d6dd9588f3537dc965b353
Recorrido completo: pass
Un Administrador y cero adicionales: pass
Consumo único y limpieza: pass
Finalización UTC: 2026-09-15 00:13:00Z
Confirmación personal: confirmed
Motivo: none
```

#### 2. Santiago Casali
*Pendiente de ejecución.*

#### 3. Said Quioto
*Pendiente de ejecución.*

#### 4. Samuel Olmos
*Pendiente de ejecución.*

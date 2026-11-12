defmodule OrigenWeb.ActivationComponents do
  @moduledoc """
  Shared layout and fields for the internal account activation pages
  (`/activar` and `/administrador/activar`), styled like `/login`.
  """
  use Phoenix.Component
  use PetalComponents

  use Phoenix.VerifiedRoutes,
    endpoint: OrigenWeb.Endpoint,
    router: OrigenWeb.Router,
    statics: OrigenWeb.static_paths()

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def activation_page(assigns) do
    ~H"""
    <main data-theme="light" class="min-h-screen bg-surface py-8 text-text sm:py-12">
      <.container max_width="sm">
        <div class="mx-auto flex w-full max-w-md flex-col gap-6">
          <header class="flex flex-col items-center gap-3 text-center">
            <img
              src={~p"/images/origen-logo-primary.png"}
              alt=""
              width="56"
              height="55"
              class="shrink-0"
            />
            <div class="flex flex-col gap-1">
              <.text_small class="text-text-muted">Origen - Gestión de turnos</.text_small>
              <h1 class="pc-h2 text-text">{@title}</h1>
            </div>
            <.text_muted :if={@subtitle} class="text-text-muted">{@subtitle}</.text_muted>
          </header>

          <.card variant="basic">
            <.card_content class="flex flex-col gap-6">
              {render_slot(@inner_block)}
            </.card_content>
          </.card>
        </div>
      </.container>
    </main>
    """
  end

  attr :error, :string, default: nil

  def activation_error(assigns) do
    ~H"""
    <.alert :if={@error} id="activation-error" color="danger" variant="callout" with_icon>
      {@error}
    </.alert>
    """
  end

  attr :totp_uri, :string, default: nil

  def totp_enrollment(assigns) do
    ~H"""
    <section :if={@totp_uri} class="flex flex-col gap-3">
      <h2 class="text-lg font-semibold text-text">Configurá tu autenticador (TOTP)</h2>
      <.text_muted class="text-text-muted">
        Escaneá este código QR con Google Authenticator, 1Password o tu aplicación preferida.
      </.text_muted>
      <div class="mx-auto w-fit rounded-lg border border-gray-200 bg-white p-4">
        <.qr_code
          value={@totp_uri}
          background="white"
          label="Código QR para enrolar autenticador"
          class="size-48 text-gray-900"
        />
      </div>
      <.field_help_text class="mt-0 text-center text-text-muted">
        ¿No podés escanear? Clave de configuración:
      </.field_help_text>
      <code
        data-totp-uri={@totp_uri}
        class="block break-all rounded bg-gray-100 p-2 text-center font-mono text-xs"
      >
        {@totp_uri}
      </code>
    </section>
    """
  end

  attr :password_only, :boolean, required: true

  def credential_fields(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <.field
        id="password"
        name="password"
        type="password"
        label="Contraseña"
        value=""
        required
        minlength="12"
        autocomplete="new-password"
        aria-describedby="password-help"
        label_class="text-text"
        no_margin
      />
      <.field_help_text id="password-help" class="mt-0 text-text-muted">
        La contraseña con la que vas a iniciar sesión. Mínimo 12 caracteres.
      </.field_help_text>
    </div>

    <div class="flex flex-col gap-2">
      <.field
        id="password_confirmation"
        name="password_confirmation"
        type="password"
        label="Confirmar contraseña"
        value=""
        required
        minlength="12"
        autocomplete="new-password"
        aria-describedby="password_confirmation-help"
        label_class="text-text"
        no_margin
      />
      <.field_help_text id="password_confirmation-help" class="mt-0 text-text-muted">
        Repetí la misma contraseña.
      </.field_help_text>
    </div>

    <div :if={!@password_only} class="flex flex-col gap-2">
      <.field
        id="totp_code"
        name="totp_code"
        type="text"
        label="Código del autenticador"
        value=""
        required
        inputmode="numeric"
        pattern="[0-9]{6}"
        autocomplete="one-time-code"
        aria-describedby="totp_code-help"
        label_class="text-text"
        no_margin
      />
      <.field_help_text id="totp_code-help" class="mt-0 text-text-muted">
        Los 6 dígitos que te muestra la app después de escanear el QR.
      </.field_help_text>
    </div>
    """
  end

  attr :csrf_token, :string, required: true
  attr :action, :string, required: true
  attr :title, :string, required: true

  def exchange_page(assigns) do
    ~H"""
    <.activation_page title={@title}>
      <.text_muted id="activation-status" class="text-center text-text-muted">
        Verificando la invitación…
      </.text_muted>
      <meta name="_csrf_token" content={@csrf_token} />
      <form id="fragment-exchange" action={@action} method="post" hidden>
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <input id="invitation-id" type="hidden" name="invitation_id" />
        <input id="invitation-token" type="hidden" name="token" />
      </form>

      <script>
        (() => {
          const fragment = new URLSearchParams(window.location.hash.slice(1));
          const invitationId = fragment.get("invitation_id");
          const token = fragment.get("token");
          history.replaceState(null, "", window.location.pathname);

          if (/^[1-9][0-9]*$/.test(invitationId || "") && token) {
            const form = document.getElementById("fragment-exchange");
            document.getElementById("invitation-id").value = invitationId;
            document.getElementById("invitation-token").value = token;
            form.submit();
          } else {
            document.getElementById("activation-status").textContent =
              "La invitación no está disponible. Pedí un enlace nuevo.";
          }
        })();
      </script>
    </.activation_page>
    """
  end
end

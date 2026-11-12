defmodule OrigenWeb.InternalSessionHTML do
  use OrigenWeb, :html

  def new(assigns) do
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
              <h1 class="pc-h2 text-text">Iniciar sesión</h1>
            </div>
            <.text_muted :if={!@password_only} class="text-text-muted">
              Ingresá con tu cuenta interna y el código actual de tu aplicación autenticadora.
            </.text_muted>
            <.text_muted :if={@password_only} class="text-text-muted">
              Ingresá con el email y la contraseña de tu cuenta interna.
            </.text_muted>
          </header>

          <.card variant="basic">
            <.card_content class="flex flex-col gap-6">
              <.alert
                :if={@error}
                id="login-error"
                color="danger"
                variant="callout"
                with_icon
              >
                {@error}
              </.alert>

              <form
                id="internal-login-form"
                action={~p"/login"}
                method="post"
                class="flex flex-col gap-4"
              >
                <input type="hidden" name="_csrf_token" value={@csrf_token} />

                <div class="flex flex-col gap-2">
                  <.field
                    id="identifier"
                    name="identifier"
                    type="text"
                    label="Email o ID de cuenta"
                    value=""
                    required
                    autocomplete="username"
                    aria-describedby="identifier-help"
                    label_class="text-text"
                    no_margin
                  />
                  <.field_help_text id="identifier-help" class="mt-0 text-text-muted">
                    El email con el que te invitaron (por ejemplo, dra.garcia@clinicaorigen.com).
                  </.field_help_text>
                </div>

                <div class="flex flex-col gap-2">
                  <.field
                    id="password"
                    name="password"
                    type="password"
                    label="Contraseña"
                    value=""
                    required
                    autocomplete="current-password"
                    aria-describedby="password-help"
                    label_class="text-text"
                    no_margin
                  />
                  <.field_help_text id="password-help" class="mt-0 text-text-muted">
                    La contraseña que definiste al activar tu cuenta.
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
                    Los 6 dígitos actuales que te muestra tu app de autenticación (la que configuraste con el QR).
                  </.field_help_text>
                </div>

                <div class="pt-2">
                  <.button type="submit" color="primary" size="lg" class="w-full">
                    Ingresar
                  </.button>
                </div>
              </form>

              <div class="text-center">
                <.link
                  id="patient-access-link"
                  href={~p"/paciente/acceso"}
                  class="inline-block rounded-md px-2 py-2 text-sm font-medium text-text-muted underline underline-offset-4 hover:text-text focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                >
                  Acceder como paciente
                </.link>
              </div>
            </.card_content>
          </.card>
        </div>
      </.container>
    </main>
    """
  end
end

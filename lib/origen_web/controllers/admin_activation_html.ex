defmodule OrigenWeb.AdminActivationHTML do
  use OrigenWeb, :html

  import OrigenWeb.ActivationComponents

  def exchange(assigns) do
    ~H"""
    <.exchange_page
      title="Activar cuenta de administrador"
      action={~p"/administrador/activar/intercambiar"}
      csrf_token={@csrf_token}
    />
    """
  end

  def enrollment(assigns) do
    ~H"""
    <.activation_page
      title="Activar cuenta de administrador"
      subtitle="Elegí el email y la contraseña con los que vas a iniciar sesión."
    >
      <.activation_error error={@error} />

      <.totp_enrollment totp_uri={@totp_uri} />

      <form
        id="admin-activation-form"
        action={~p"/administrador/activar"}
        method="post"
        class="flex flex-col gap-4"
      >
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <div class="flex flex-col gap-2">
          <.field
            id="email"
            name="email"
            type="email"
            label="Email"
            value=""
            required
            autocomplete="email"
            aria-describedby="email-help"
            label_class="text-text"
            no_margin
          />
          <.field_help_text id="email-help" class="mt-0 text-text-muted">
            Con este email vas a iniciar sesión como administrador.
          </.field_help_text>
        </div>
        <.credential_fields password_only={@password_only} />
        <div class="pt-2">
          <.button type="submit" color="primary" size="lg" class="w-full">
            Activar cuenta
          </.button>
        </div>
      </form>
    </.activation_page>
    """
  end
end

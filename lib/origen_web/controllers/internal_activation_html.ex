defmodule OrigenWeb.InternalActivationHTML do
  use OrigenWeb, :html

  import OrigenWeb.ActivationComponents

  def exchange(assigns) do
    ~H"""
    <.exchange_page
      title="Activar cuenta"
      action={~p"/activar/intercambiar"}
      csrf_token={@csrf_token}
    />
    """
  end

  def enrollment(assigns) do
    ~H"""
    <.activation_page
      title="Activar cuenta"
      subtitle="Elegí tu contraseña. Después vas a iniciar sesión con el email con el que te invitaron."
    >
      <.activation_error error={@error} />
      <.totp_enrollment totp_uri={@totp_uri} />

      <form
        id="internal-activation-form"
        action={~p"/activar"}
        method="post"
        class="flex flex-col gap-4"
      >
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
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

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
      subtitle="Elegí la contraseña de la cuenta de administrador."
    >
      <.activation_error error={@error} />

      <div
        :if={@account_id}
        id="login-identifier"
        data-login-identifier={@account_id}
        class="rounded-lg border border-gray-200 bg-gray-50 p-4 text-sm text-text"
      >
        Esta cuenta no tiene email. Para iniciar sesión vas a usar el ID de cuenta
        <strong class="font-semibold">{@account_id}</strong>
        y la contraseña que elijas acá.
      </div>

      <.totp_enrollment totp_uri={@totp_uri} />

      <form
        id="admin-activation-form"
        action={~p"/administrador/activar"}
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

defmodule OrigenWeb.InternalSessionHTML do
  use OrigenWeb, :html

  def new(assigns) do
    ~H"""
    <main class="mx-auto max-w-lg p-8">
      <h1 class="text-2xl font-semibold">Iniciar sesión</h1>
      <p :if={@error} role="alert" class="mt-4">{@error}</p>
      <form action={~p"/login"} method="post" class="mt-6 space-y-4">
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <.input
          name="identifier"
          type="text"
          label="Email o ID de cuenta"
          value=""
          required
          autocomplete="username"
        />
        <p class="text-xs text-gray-500 -mt-2">
          El email con el que te invitaron (por ejemplo, dra.garcia@clinicaorigen.com).
        </p>
        <.input
          name="password"
          type="password"
          label="Contraseña"
          value=""
          required
          autocomplete="current-password"
        />
        <p class="text-xs text-gray-500 -mt-2">
          La contraseña que definiste al activar tu cuenta.
        </p>
        <.input
          name="totp_code"
          type="text"
          label="Código del autenticador"
          value=""
          required
          inputmode="numeric"
          pattern="[0-9]{6}"
          autocomplete="one-time-code"
        />
        <p class="text-xs text-gray-500 -mt-2">
          Los 6 dígitos actuales que te muestra tu app de autenticación (la que configuraste con el QR).
        </p>
        <button type="submit" class="btn btn-primary">Ingresar</button>
      </form>
    </main>
    """
  end
end

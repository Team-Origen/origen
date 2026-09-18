defmodule OrigenWeb.InternalSessionHTML do
  use OrigenWeb, :html

  def new(assigns) do
    ~H"""
    <main class="mx-auto max-w-lg p-8">
      <h1 class="text-2xl font-semibold">Sign in</h1>
      <p :if={@error} role="alert" class="mt-4">{@error}</p>
      <form action={~p"/login"} method="post" class="mt-6 space-y-4">
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <.input
          name="identifier"
          type="text"
          label="Email or account ID"
          value=""
          required
          autocomplete="username"
        />
        <.input
          name="password"
          type="password"
          label="Password"
          value=""
          required
          autocomplete="current-password"
        />
        <.input
          name="totp_code"
          type="text"
          label="Authenticator code"
          value=""
          required
          inputmode="numeric"
          pattern="[0-9]{6}"
          autocomplete="one-time-code"
        />
        <button type="submit" class="btn btn-primary">Sign in</button>
      </form>
    </main>
    """
  end
end

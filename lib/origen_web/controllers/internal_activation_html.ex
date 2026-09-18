defmodule OrigenWeb.InternalActivationHTML do
  use OrigenWeb, :html

  def exchange(assigns) do
    ~H"""
    <main class="mx-auto max-w-lg p-8">
      <h1 class="text-2xl font-semibold">Account activation</h1>
      <p id="activation-status" class="mt-4">Checking invitation…</p>
      <meta name="_csrf_token" content={@csrf_token} />
      <form id="fragment-exchange" action={~p"/activate/exchange"} method="post" hidden>
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
              "Activation invitation is unavailable.";
          }
        })();
      </script>
    </main>
    """
  end

  def enrollment(assigns) do
    ~H"""
    <main class="mx-auto max-w-lg p-8">
      <h1 class="text-2xl font-semibold">Secure internal account</h1>
      <p :if={@error} role="alert" class="mt-4">{@error}</p>
      <section :if={@totp_uri} class="mt-6">
        <h2 class="font-semibold">Add the authenticator factor</h2>
        <p>Scan this one-time enrollment payload with your authenticator application.</p>
        <code data-totp-uri={@totp_uri} class="mt-2 block break-all">{@totp_uri}</code>
      </section>
      <form action={~p"/activate"} method="post" class="mt-6 space-y-4">
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <.input
          name="password"
          type="password"
          label="Password"
          value=""
          required
          minlength="12"
          autocomplete="new-password"
        />
        <.input
          name="password_confirmation"
          type="password"
          label="Confirm password"
          value=""
          required
          minlength="12"
          autocomplete="new-password"
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
        <button type="submit" class="btn btn-primary">Activate account</button>
      </form>
    </main>
    """
  end
end

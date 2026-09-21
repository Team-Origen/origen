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
        <h2 class="font-semibold text-lg">Configurar factor de autenticación (TOTP)</h2>
        
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          Escaneá este código QR con Google Authenticator, 1Password o tu aplicación preferida.
        </p>
        
        <div class="flex justify-center p-4 mt-4 bg-white rounded-lg border border-gray-200 w-fit mx-auto">
          <.qr_code
            value={@totp_uri}
            background="white"
            label="Código QR para enrolar autenticador"
            class="size-48 text-gray-900"
          />
        </div>
        
        <div class="mt-3 text-xs text-gray-500 text-center">
          ¿No podés escanear? Clave de configuración:
        </div>
        
        <code
          data-totp-uri={@totp_uri}
          class="mt-1 block break-all text-xs font-mono bg-gray-100 dark:bg-gray-800 p-2 rounded text-center"
        >
          {@totp_uri}
        </code>
      </section>
      
      <form action={~p"/activate"} method="post" class="mt-6 space-y-4">
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <.input
          name="password"
          type="password"
          label="Contraseña"
          value=""
          required
          minlength="12"
          autocomplete="new-password"
        />
        <p class="text-xs text-gray-500 -mt-2">
          Elegí tu contraseña para iniciar sesión. Mínimo 12 caracteres.
        </p>
        
        <.input
          name="password_confirmation"
          type="password"
          label="Confirmar contraseña"
          value=""
          required
          minlength="12"
          autocomplete="new-password"
        />
        <p class="text-xs text-gray-500 -mt-2">
          Repetí la misma contraseña para verificar que la escribiste bien.
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
          Los 6 dígitos que te muestra la app después de escanear el QR de arriba.
        </p>
         <button type="submit" class="btn btn-primary">Activate account</button>
      </form>
    </main>
    """
  end
end

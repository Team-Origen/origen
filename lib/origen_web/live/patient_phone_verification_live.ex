defmodule OrigenWeb.PatientPhoneVerificationLive do
  use OrigenWeb, :live_view
  alias Origen.Patients
  alias Origen.Patients.PhoneVerificationConfig

  @impl true
  def mount(_params, session, socket) do
    email =
      session["patient_email"] ||
        if(Application.get_env(:origen, :env) == :dev, do: "paciente@example.test")

    profile =
      if email,
        do:
          (case Patients.get_or_create_profile(email) do
             {:ok, p} -> p
             _ -> nil
           end)

    state = if profile && profile.phone_verified, do: :verified, else: :input

    {:ok,
     assign(socket,
       profile: profile,
       email: email,
       phone: (profile && profile.phone) || "",
       code: "",
       state: state,
       error_message: nil,
       info_message: nil
     )}
  end

  @impl true
  def handle_event("validate", %{"verification" => %{"code" => code}}, socket) do
    sanitized =
      code
      |> String.replace(~r/[^0-9]/, "")
      |> String.slice(0, PhoneVerificationConfig.code_length())

    {:noreply, assign(socket, code: sanitized, error_message: nil)}
  end

  @impl true
  def handle_event("verify", %{"verification" => %{"code" => code}}, socket) do
    profile = socket.assigns.profile
    clean_code = String.trim(code)

    cond do
      is_nil(profile) ->
        error_reply(socket, "Sesión de paciente no encontrada.")

      String.length(clean_code) != PhoneVerificationConfig.code_length() ->
        error_reply(socket, "El código debe tener exactamente 6 dígitos numéricos.")

      true ->
        case Patients.verify_phone_code(profile, clean_code) do
          {:ok, %{profile: updated}} ->
            {:noreply,
             assign(socket,
               profile: updated,
               state: :verified,
               error_message: nil,
               info_message: "¡Teléfono verificado con éxito!"
             )}

          {:error, :invalid_code} ->
            error_reply(
              socket,
              "El código ingresado es incorrecto. Revisá el correo e intentá nuevamente."
            )

          {:error, :max_attempts_exceeded} ->
            error_reply(
              socket,
              "Superaste el límite de 3 intentos fallidos. Solicitá un nuevo código.",
              :locked
            )

          {:error, :challenge_expired} ->
            error_reply(
              socket,
              "El código ha vencido (validez de 10 minutos). Solicitá un nuevo código.",
              :expired
            )

          {:error, :challenge_consumed} ->
            error_reply(
              socket,
              "Este código ya fue utilizado. Tu teléfono ya está verificado o pedí uno nuevo."
            )

          {:error, :no_active_challenge} ->
            error_reply(
              socket,
              "No hay ningún desafío de verificación pendiente. Solicitá un código."
            )

          {:error, :phone_mismatch} ->
            error_reply(socket, "El número telefónico no coincide con el desafío emitido.")

          {:error, reason} ->
            error_reply(socket, "Error al verificar: #{inspect(reason)}")
        end
    end
  end

  @impl true
  def handle_event("resend_code", _params, socket) do
    profile = socket.assigns.profile
    phone = profile && profile.phone

    cond do
      is_nil(profile) ->
        error_reply(socket, "Sesión de paciente no encontrada.")

      is_nil(phone) or String.trim(phone) == "" ->
        error_reply(socket, "No tenés un número telefónico registrado en tu perfil.")

      true ->
        case Patients.request_phone_verification(profile, phone) do
          {:ok, _} ->
            {:noreply,
             assign(socket,
               state: :input,
               code: "",
               error_message: nil,
               info_message: "Nuevo código de 6 dígitos enviado a tu correo (#{profile.email})."
             )}

          {:error, :cooldown_active} ->
            error_reply(socket, "Debés esperar 60 segundos entre solicitudes de reenvío.")

          {:error, :hourly_limit_exceeded} ->
            error_reply(
              socket,
              "Superaste el límite de 5 solicitudes por hora. Intentá más tarde."
            )

          {:error, reason} ->
            error_reply(socket, "Error al reenviar código: #{inspect(reason)}")
        end
    end
  end

  defp error_reply(socket, msg, state \\ nil) do
    socket = if state, do: assign(socket, state: state), else: socket
    {:noreply, assign(socket, error_message: msg)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#F6F6F4] py-12 px-4 sm:px-6 lg:px-8 font-inter">
      <div class="max-w-md w-full bg-white border border-[#AFBAB4]/40 rounded-xl shadow-[0px_4px_20px_rgba(10,56,71,0.06)] p-8 sm:p-10">
        <%= if @state == :verified do %>
          <div class="text-center py-4">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-[#DDE6DB] mb-6">
              <.icon name="hero-check" class="h-8 w-8 text-[#0A3847]" />
            </div>
            <h2 class="text-2xl font-bold text-[#0A3847] mb-3">¡Teléfono Verificado!</h2>
            <p class="text-sm text-[#35545A] mb-6">
              El número
              <strong class="font-semibold text-[#0A3847]">{PhoneVerificationConfig.sanitize_phone(
                @phone
              )}</strong>
              fue verificado con éxito.
            </p>
            <div class="bg-[#F6F6F4] border border-[#DDE6DB] rounded-lg p-4 mb-6 text-left">
              <div class="flex items-center space-x-2 text-xs font-semibold text-[#0A3847]">
                <.icon name="hero-shield-check" class="h-4 w-4 text-[#0A3847]" />
                <span>Perfil Habilitado para Reservas</span>
              </div>
              <p class="mt-1 text-xs text-[#35545A]">
                Tu cuenta de paciente ahora cumple con todos los requisitos para realizar reservas autónomas de turnos.
              </p>
            </div>
            <.link
              navigate={~p"/patient/profile/complete"}
              class="w-full inline-flex justify-center items-center py-2.5 px-4 rounded-md shadow-sm text-sm font-semibold text-white bg-[#0A3847] hover:bg-[#35545A] transition duration-150"
            >
              Volver a Mi Perfil
            </.link>
          </div>
        <% else %>
          <div class="mb-6">
            <h1 class="text-2xl font-semibold text-[#0A3847] tracking-tight">Verificar Teléfono</h1>
            <p class="mt-2 text-sm text-[#35545A]">
              Ingresá el código de 6 dígitos que enviamos a tu correo para verificar el número <strong class="text-[#0A3847]">{PhoneVerificationConfig.sanitize_phone(@phone)}</strong>.
            </p>
          </div>

          <%= if @info_message do %>
            <div class="mb-5 p-3 rounded-md bg-[#DDE6DB]/50 border border-[#AFBAB4] text-xs font-medium text-[#0A3847] flex items-center gap-2">
              <.icon name="hero-information-circle" class="w-4 h-4 text-[#0A3847]" />
              <span>{@info_message}</span>
            </div>
          <% end %>

          <%= if @error_message do %>
            <div class="mb-5 p-3 rounded-md bg-red-50 border border-red-200 text-xs font-medium text-red-800 flex items-start gap-2">
              <.icon
                name="hero-exclamation-triangle"
                class="w-4 h-4 text-red-600 mt-0.5 flex-shrink-0"
              />
              <span>{@error_message}</span>
            </div>
          <% end %>

          <form
            phx-change="validate"
            phx-submit="verify"
            id="phone-verification-form"
            class="space-y-6"
          >
            <div>
              <label
                for="verification_code"
                class="block text-xs font-semibold text-[#35545A] mb-2 text-center"
              >Código de 6 dígitos</label>
              <input
                type="text"
                name="verification[code]"
                id="verification_code"
                value={@code}
                inputmode="numeric"
                maxlength="6"
                placeholder="123456"
                autofocus
                required
                disabled={@state in [:locked, :expired]}
                class="w-full text-center text-3xl font-mono font-bold tracking-[0.5em] py-3 px-4 rounded-lg border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847] bg-[#F6F6F4]/50 disabled:bg-gray-100 disabled:cursor-not-allowed"
              />
            </div>

            <button
              type="submit"
              disabled={@state in [:locked, :expired] or String.length(@code) != 6}
              class="w-full flex justify-center py-2.5 px-4 border border-transparent rounded-md shadow-sm text-sm font-semibold text-white bg-[#0A3847] hover:bg-[#35545A] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#0A3847] transition duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Verificar Código
            </button>
          </form>

          <div class="mt-6 text-center border-t border-[#AFBAB4]/30 pt-4">
            <p class="text-xs text-[#35545A] mb-2">¿No recibiste el código o ya venció?</p>
            <button
              type="button"
              phx-click="resend_code"
              class="text-xs font-semibold text-[#0A3847] hover:underline focus:outline-none"
            >
              Reenviar nuevo código a mi correo
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end

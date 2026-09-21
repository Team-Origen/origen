defmodule OrigenWeb.PatientAccessLive do
  @moduledoc """
  LiveView for patient passwordless access request via Magic Link.
  Implements real-time email validation and a non-enumerating confirmation response.
  """

  use OrigenWeb, :live_view

  alias Ecto.Changeset

  @types %{email: :string}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, to_form(new_changeset(), as: :access))
     |> assign(:submitted, false)
     |> assign(:submitted_email, nil)}
  end

  @impl true
  def handle_event("validate", %{"access" => params}, socket) do
    changeset = build_changeset(params)
    {:noreply, assign(socket, :form, to_form(changeset, as: :access))}
  end

  @impl true
  def handle_event("submit", %{"access" => params}, socket) do
    changeset = build_changeset(params)

    if changeset.valid? do
      email = Changeset.get_change(changeset, :email)

      # Security: Non-enumerating response (does not disclose account existence)
      {:noreply,
       socket
       |> assign(:submitted, true)
       |> assign(:submitted_email, email)}
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :access))}
    end
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(new_changeset(), as: :access))
     |> assign(:submitted, false)
     |> assign(:submitted_email, nil)}
  end

  defp new_changeset(params \\ %{}) do
    {%{}, @types}
    |> Changeset.cast(params, [:email])
  end

  defp build_changeset(params) do
    new_changeset(params)
    |> Changeset.validate_required([:email], message: "no puede estar en blanco")
    |> validate_no_whitespace(:email)
    |> Changeset.validate_format(
      :email,
      ~r/^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$/,
      message: "debe ser un correo electrónico válido"
    )
    |> Map.put(:action, :validate)
  end

  defp validate_no_whitespace(changeset, field) do
    case Changeset.get_change(changeset, field) do
      nil ->
        changeset

      value when is_binary(value) ->
        if String.contains?(value, " ") do
          Changeset.add_error(changeset, field, "debe ser un correo electrónico válido")
        else
          changeset
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#F6F6F4] py-12 px-4 sm:px-6 lg:px-8 font-inter">
      <div class="max-w-md w-full bg-white border border-[#AFBAB4]/40 rounded-xl shadow-[0px_4px_20px_rgba(10,56,71,0.06)] p-8">
        <div :if={not @submitted}>
          <div class="mb-8">
            <h1 class="text-2xl font-semibold text-[#0A3847] font-inter tracking-tight">
              Acceso para Pacientes
            </h1>
            <p class="mt-2 text-sm text-[#35545A] font-inter">
              Ingresá tu correo electrónico para recibir un enlace de acceso seguro sin contraseña.
            </p>
          </div>

          <.form
            for={@form}
            id="patient-access-form"
            phx-change="validate"
            phx-submit="submit"
            class="space-y-6"
          >
            <.field
              field={@form[:email]}
              type="email"
              label="Correo electrónico"
              placeholder="paciente@example.test"
              required
              autocomplete="email"
              class="py-[12px] px-[16px] rounded-md w-full border border-[#AFBAB4] text-[#0A3847] placeholder-[#AFBAB4] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847] font-inter"
              label_class="block text-[13px] font-semibold leading-[18px] tracking-[0.05em] text-[#35545A] font-inter mb-1"
            />

            <.button
              type="submit"
              class="w-full bg-[#0A3847] text-white h-[44px] px-6 rounded-md font-inter font-semibold hover:bg-[#072732] focus:ring-2 focus:ring-[#0A3847] focus:ring-offset-2 cursor-pointer transition-colors shadow-sm"
            >
              Enviar enlace de acceso
            </.button>
          </.form>
        </div>

        <div :if={@submitted} class="text-center py-4">
          <div class="mx-auto flex items-center justify-center h-14 w-14 rounded-full bg-[#DDE6DB] mb-4">
            <.icon name="hero-envelope-open" class="h-7 w-7 text-[#0A3847]" />
          </div>
          <h2 class="text-xl font-semibold text-[#0A3847] mb-2 font-inter">
            Revisá tu casilla de correo
          </h2>
          <p class="text-sm text-[#35545A] mb-4 leading-relaxed font-inter">
            Si el correo ingresado corresponde a un paciente registrado, enviamos un enlace de acceso temporal para que puedas ingresar.
          </p>
          <p class="text-xs text-[#35545A]/80 mb-6 font-inter">
            El enlace es de un solo uso y expira en pocos minutos por motivos de seguridad.
          </p>
          <.button
            id="reset-access-button"
            phx-click="reset"
            class="w-full bg-white border border-[#35545A] text-[#35545A] h-[40px] px-4 rounded-md font-inter font-medium hover:bg-[#DDE6DB]/30 cursor-pointer transition-colors"
          >
            Ingresar otro correo
          </.button>
        </div>
      </div>
    </div>
    """
  end
end

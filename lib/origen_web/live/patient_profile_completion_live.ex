defmodule OrigenWeb.PatientProfileCompletionLive do
  use OrigenWeb, :live_view
  alias Ecto.Changeset
  alias Origen.Patients
  alias Origen.Patients.Persona

  @doc_options [
    {"DNI", "dni"},
    {"Pasaporte", "passport"},
    {"Cédula / Tarjeta de Identidad", "identity_card"},
    {"Otro", "other"}
  ]

  @types %{
    first_name: :string,
    last_name: :string,
    document_type: :string,
    document_number: :string,
    birthdate: :date,
    phone: :string
  }

  @impl true
  def mount(_params, session, socket) do
    patient_email =
      session["patient_email"] ||
        if Application.get_env(:origen, :env) == :dev, do: "paciente@example.test", else: nil

    profile =
      if patient_email do
        case Patients.get_or_create_profile(patient_email) do
          {:ok, p} -> p
          _ -> nil
        end
      else
        nil
      end

    {:ok,
     socket
     |> assign(:patient_email, patient_email)
     |> assign(:profile, profile)
     |> assign(:outcome, nil)
     |> assign(:doc_options, @doc_options)
     |> assign(:form, to_form(new_changeset(), as: :profile))}
  end

  @impl true
  def handle_event("validate", %{"profile" => params}, socket) do
    changeset = build_changeset(params)
    {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}
  end

  @impl true
  def handle_event("save", %{"profile" => params}, socket) do
    changeset = build_changeset(params)

    if changeset.valid? do
      email = socket.assigns.patient_email || "paciente@example.test"
      attrs = changeset.changes

      case Patients.complete_profile(email, attrs) do
        {:ok, %{outcome: :completed, profile: updated_profile}} ->
          {:noreply, socket |> assign(:profile, updated_profile) |> assign(:outcome, :completed)}

        {:ok, %{outcome: :derived_to_secretary, profile: updated_profile}} ->
          {:noreply,
           socket |> assign(:profile, updated_profile) |> assign(:outcome, :derived_to_secretary)}

        {:error, %Changeset{} = err_changeset} ->
          {:noreply, assign(socket, :form, to_form(err_changeset, as: :profile))}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Ocurrió un error al procesar los datos.")}
      end
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}
    end
  end

  defp new_changeset(params \\ %{}) do
    {%{}, @types}
    |> Changeset.cast(params, [
      :first_name,
      :last_name,
      :document_type,
      :document_number,
      :birthdate,
      :phone
    ])
  end

  defp build_changeset(params) do
    new_changeset(params)
    |> Changeset.validate_required(
      [:first_name, :last_name, :document_type, :document_number, :birthdate],
      message: "no puede estar en blanco"
    )
    |> Changeset.validate_inclusion(:document_type, Persona.document_types(),
      message: "debe ser un tipo de documento válido"
    )
    |> normalize_doc_number()
    |> Changeset.validate_format(:document_number, ~r/^[A-Za-z0-9]{1,32}$/,
      message: "debe ser alfanumérico válido"
    )
    |> validate_birthdate()
    |> Map.put(:action, :validate)
  end

  defp normalize_doc_number(changeset) do
    case Changeset.get_change(changeset, :document_number) do
      nil ->
        changeset

      num when is_binary(num) ->
        Changeset.put_change(changeset, :document_number, Persona.normalize_number(num))
    end
  end

  defp validate_birthdate(changeset) do
    Changeset.validate_change(changeset, :birthdate, fn _, date ->
      if Date.compare(date, Date.utc_today()) == :lt do
        []
      else
        [birthdate: "debe ser una fecha en el pasado"]
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#F6F6F4] py-12 px-4 sm:px-6 lg:px-8 font-inter">
      <div class="max-w-xl w-full bg-white border border-[#AFBAB4]/40 rounded-xl shadow-[0px_4px_20px_rgba(10,56,71,0.06)] p-8 sm:p-10">
        <div :if={is_nil(@outcome)}>
          <div class="mb-8">
            <h1 class="text-2xl sm:text-3xl font-semibold text-[#0A3847] tracking-tight">
              Completar Perfil
            </h1>

            <p class="mt-2 text-sm text-[#35545A]">
              Ingresá tus datos de identidad para habilitar tu perfil de paciente.
            </p>
          </div>

          <.form
            for={@form}
            id="patient-profile-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.field
                field={@form[:first_name]}
                type="text"
                label="Nombres"
                placeholder="Ej. Juan Manuel"
                required
                class="py-2.5 px-3.5 rounded-md w-full border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847]"
                label_class="block text-xs font-semibold text-[#35545A] mb-1"
              />
              <.field
                field={@form[:last_name]}
                type="text"
                label="Apellidos"
                placeholder="Ej. Pérez"
                required
                class="py-2.5 px-3.5 rounded-md w-full border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847]"
                label_class="block text-xs font-semibold text-[#35545A] mb-1"
              />
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.field
                field={@form[:document_type]}
                type="select"
                label="Tipo de documento"
                options={@doc_options}
                prompt="Seleccionar tipo"
                required
                class="py-2.5 px-3.5 rounded-md w-full border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847]"
                label_class="block text-xs font-semibold text-[#35545A] mb-1"
              />
              <.field
                field={@form[:document_number]}
                type="text"
                label="Número de documento"
                placeholder="Sin puntos ni espacios"
                required
                class="py-2.5 px-3.5 rounded-md w-full border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847]"
                label_class="block text-xs font-semibold text-[#35545A] mb-1"
              />
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.field
                field={@form[:birthdate]}
                type="date"
                label="Fecha de nacimiento"
                required
                class="py-2.5 px-3.5 rounded-md w-full border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847]"
                label_class="block text-xs font-semibold text-[#35545A] mb-1"
              />
              <.field
                field={@form[:phone]}
                type="tel"
                label="Teléfono (opcional)"
                placeholder="Ej. +5491122334455"
                class="py-2.5 px-3.5 rounded-md w-full border border-[#AFBAB4] text-[#0A3847] focus:ring-2 focus:ring-[#0A3847] focus:border-[#0A3847]"
                label_class="block text-xs font-semibold text-[#35545A] mb-1"
              />
            </div>

            <p class="text-xs text-[#35545A]/70 pt-2">
              * El número telefónico se verificará por separado antes de realizar tu primera reserva.
            </p>

            <.button
              type="submit"
              class="w-full bg-[#0A3847] text-white h-[44px] px-6 rounded-md font-semibold hover:bg-[#072732] focus:ring-2 focus:ring-[#0A3847] focus:ring-offset-2 transition-colors cursor-pointer mt-4"
            >
              Guardar y Completar Perfil
            </.button>
          </.form>
        </div>

        <div :if={@outcome == :completed} id="profile-completed-view" class="text-center py-4">
          <div class="mx-auto flex items-center justify-center h-14 w-14 rounded-full bg-[#DDE6DB] mb-4">
            <.icon name="hero-check-circle" class="h-8 w-8 text-[#0A3847]" />
          </div>

          <h2 class="text-2xl font-semibold text-[#0A3847] mb-2">¡Perfil Completado!</h2>

          <p class="text-sm text-[#35545A] mb-4 leading-relaxed">
            Tus datos de identidad fueron registrados correctamente en el sistema.
          </p>

          <div class="bg-gray-50 border border-[#AFBAB4]/30 rounded-lg p-4 mb-6 text-left text-xs text-[#35545A] space-y-1">
            <p><strong>Estado:</strong> Datos obligatorios completos</p>

            <p><strong>Teléfono:</strong> Pendiente de verificación (requerido para reservar)</p>
          </div>

          <.link
            navigate={~p"/"}
            class="inline-block w-full bg-[#0A3847] text-white py-2.5 px-4 rounded-md font-semibold hover:bg-[#072732] transition-colors text-center"
          >
            Ir al inicio
          </.link>
        </div>

        <div
          :if={@outcome == :derived_to_secretary}
          id="profile-collision-view"
          class="text-center py-4"
        >
          <div class="mx-auto flex items-center justify-center h-14 w-14 rounded-full bg-amber-100 mb-4">
            <.icon name="hero-exclamation-triangle" class="h-8 w-8 text-amber-800" />
          </div>

          <h2 class="text-2xl font-semibold text-[#0A3847] mb-2">
            Verificación de Identidad Requerida
          </h2>

          <p class="text-sm text-[#35545A] mb-4 leading-relaxed">
            El documento ingresado ya se encuentra registrado en nuestro sistema. Para proteger la seguridad y privacidad de tu cuenta, tu solicitud fue derivada al equipo de Secretaría.
          </p>

          <p class="text-xs text-gray-500 mb-6 leading-relaxed">
            Un miembro de Secretaría validará tu identidad documental para habilitar tu acceso. No es necesario que vuelvas a ingresar tus datos.
          </p>

          <.link
            navigate={~p"/"}
            class="inline-block w-full bg-white border border-[#35545A] text-[#35545A] py-2.5 px-4 rounded-md font-medium hover:bg-gray-50 transition-colors text-center"
          >
            Volver al inicio
          </.link>
        </div>
      </div>
    </div>
    """
  end
end

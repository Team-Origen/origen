defmodule OrigenWeb.SecretaryPatientLive do
  @moduledoc """
  LiveView for document-based person search and assisted registration (PLN-12, Issue #67).

  Allows an authenticated Secretary (or Administrator) to search Personas by
  controlled document type and normalized number, register new identities for
  the assisted booking flow, and review the resulting patient summary before
  starting an assisted reservation (#68).
  """

  use OrigenWeb, :live_view

  on_mount {OrigenWeb.InternalAuthLive, :ensure_authenticated}

  alias Ecto.Changeset
  alias Origen.Patients
  alias Origen.Patients.Persona

  @doc_options [
    {"DNI", "dni"},
    {"Pasaporte", "passport"},
    {"Cédula / Tarjeta de Identidad", "identity_card"},
    {"Otro", "other"}
  ]

  @gender_options [
    {"Femenino", "femenino"},
    {"Masculino", "masculino"},
    {"Otro", "otro"},
    {"Prefiero no decirlo", "prefiero_no_decir"}
  ]

  @gender_values Enum.map(@gender_options, &elem(&1, 1))

  @search_types %{document_type: :string, document_number: :string}
  @search_defaults %{document_type: "dni", document_number: ""}

  @register_types %{
    first_name: :string,
    last_name: :string,
    document_type: :string,
    document_number: :string,
    birthdate: :date,
    phone: :string,
    gender: :string
  }

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_role in [:secretary, :administrator] do
      {:ok,
       socket
       |> assign(:page_title, "Pacientes")
       |> assign(:doc_options, @doc_options)
       |> assign(:gender_options, @gender_options)
       |> assign(:search_form, to_form(search_changeset(%{}), as: :search))
       |> assign(:search_result, nil)
       |> assign(:registration_form, nil)
       |> assign(:registration_document, nil)
       |> assign(:registration_outcome, nil)
       |> assign(:registration_error, false)
       |> assign(:assisted_booking_notice, false)}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("validate_search", %{"search" => params}, socket) do
    {:noreply, assign(socket, :search_form, to_form(search_changeset(params), as: :search))}
  end

  def handle_event("validate_search", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("search", %{"search" => params}, socket) do
    changeset = search_changeset(params)

    if changeset.valid? do
      doc_type = Changeset.get_field(changeset, :document_type)
      doc_num = Changeset.get_field(changeset, :document_number)

      case Patients.search_persona_by_document(
             doc_type,
             doc_num,
             socket.assigns.current_internal_session.account_id
           ) do
        {:ok, nil} ->
          registration_params = %{
            "document_type" => doc_type,
            "document_number" => doc_num
          }

          {:noreply,
           socket
           |> assign(:search_result, :not_found)
           |> assign(
             :registration_form,
             to_form(register_changeset(registration_params), as: :registration)
           )
           |> assign(:registration_document, "#{doc_label(doc_type)} #{doc_num}")
           |> assign(:registration_outcome, nil)
           |> assign(:registration_error, false)
           |> assign(:assisted_booking_notice, false)}

        {:ok, %{persona: persona, profile: profile}} ->
          {:noreply,
           socket
           |> assign(:search_result, %{persona: persona, profile: profile})
           |> assign(:registration_form, nil)
           |> assign(:registration_document, nil)
           |> assign(:registration_outcome, nil)
           |> assign(:registration_error, false)
           |> assign(:assisted_booking_notice, false)}
      end
    else
      {:noreply, assign(socket, :search_form, to_form(changeset, as: :search))}
    end
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate_registration", %{"registration" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :registration_form,
       to_form(register_changeset(params), as: :registration)
     )}
  end

  def handle_event("validate_registration", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("register", %{"registration" => params}, socket) do
    changeset = register_changeset(params)

    if changeset.valid? do
      case Patients.register_or_reuse_assisted_persona(
             params,
             socket.assigns.current_internal_session.account_id
           ) do
        {:ok, %{persona: persona, profile: profile, outcome: outcome}} ->
          {:noreply,
           socket
           |> assign(:search_result, %{persona: persona, profile: profile})
           |> assign(:registration_form, nil)
           |> assign(:registration_document, nil)
           |> assign(:registration_outcome, outcome)
           |> assign(:registration_error, false)
           |> assign(:assisted_booking_notice, false)}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(:registration_error, true)
           |> assign(:registration_form, to_form(changeset, as: :registration))}
      end
    else
      {:noreply,
       socket
       |> assign(:registration_error, false)
       |> assign(:registration_form, to_form(changeset, as: :registration))}
    end
  end

  def handle_event("register", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("new_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_form, to_form(search_changeset(%{}), as: :search))
     |> assign(:search_result, nil)
     |> assign(:registration_form, nil)
     |> assign(:registration_document, nil)
     |> assign(:registration_outcome, nil)
     |> assign(:registration_error, false)
     |> assign(:assisted_booking_notice, false)}
  end

  @impl true
  def handle_event("start_assisted_booking", _params, socket) do
    {:noreply, assign(socket, :assisted_booking_notice, true)}
  end

  defp search_changeset(params) do
    {@search_defaults, @search_types}
    |> Changeset.cast(params, [:document_type, :document_number])
    |> Changeset.validate_required([:document_type, :document_number],
      message: "no puede estar en blanco"
    )
    |> Changeset.validate_inclusion(:document_type, Persona.document_types(),
      message: "debe ser un tipo de documento válido"
    )
    |> normalize_doc_number()
    |> validate_document_number_by_type()
    |> Map.put(:action, :validate)
  end

  defp register_changeset(params) do
    {%{}, @register_types}
    |> Changeset.cast(params, [
      :first_name,
      :last_name,
      :document_type,
      :document_number,
      :birthdate,
      :phone,
      :gender
    ])
    |> Changeset.validate_required(
      [:first_name, :last_name, :document_type, :document_number, :birthdate, :phone, :gender],
      message: "no puede estar en blanco"
    )
    |> Changeset.validate_inclusion(:document_type, Persona.document_types(),
      message: "debe ser un tipo de documento válido"
    )
    |> Changeset.validate_inclusion(:gender, @gender_values,
      message: "debe ser una opción válida"
    )
    |> normalize_doc_number()
    |> validate_document_number_by_type()
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

  defp validate_document_number_by_type(changeset) do
    doc_type = Changeset.get_field(changeset, :document_type)

    case Changeset.get_change(changeset, :document_number) do
      nil ->
        changeset

      num when is_binary(num) ->
        case doc_type do
          "dni" ->
            if Regex.match?(~r/^[0-9]{6,9}$/, num) do
              changeset
            else
              Changeset.add_error(
                changeset,
                :document_number,
                "el DNI debe contener solo números (entre 6 y 9 dígitos)"
              )
            end

          "passport" ->
            if Regex.match?(~r/^[A-Za-z0-9]{3,20}$/, num) do
              changeset
            else
              Changeset.add_error(
                changeset,
                :document_number,
                "el pasaporte debe ser alfanumérico (entre 3 y 20 caracteres)"
              )
            end

          _other ->
            if Regex.match?(~r/^[A-Za-z0-9]{1,32}$/, num) do
              changeset
            else
              Changeset.add_error(changeset, :document_number, "debe ser alfanumérico válido")
            end
        end
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

  defp doc_label("dni"), do: "DNI"
  defp doc_label("passport"), do: "Pasaporte"
  defp doc_label("identity_card"), do: "Cédula / Tarjeta de Identidad"
  defp doc_label("other"), do: "Otro"
  defp doc_label(doc_type), do: doc_type

  defp profile_state_label(nil), do: "Sin perfil de paciente"

  defp profile_state_label("pending_completion"), do: "Pendiente de completar"
  defp profile_state_label("completed"), do: "Completado"
  defp profile_state_label("pending_secretary_review"), do: "Pendiente de revisión de Secretaría"
  defp profile_state_label(state), do: state

  defp outcome_feedback(:created), do: "Persona registrada correctamente."
  defp outcome_feedback(:reused), do: "La persona ya estaba registrada y fue reutilizada."

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-page py-6 text-gray-900 sm:py-10">
      <.container max_width="xl">
        <div class="flex flex-col gap-6 sm:gap-8">
          <header class="space-y-2">
            <.h1 no_margin>Búsqueda de pacientes</.h1>

            <.text_muted>
              Buscá una persona por documento para reutilizar su identidad o registrarla para una reserva asistida.
            </.text_muted>
          </header>

          <section aria-labelledby="persona-search-heading">
            <.card variant="basic">
              <.card_header>
                <.h2 id="persona-search-heading" no_margin>Buscar persona</.h2>

                <:action>
                  <.button
                    :if={not is_nil(@search_result)}
                    color="secondary"
                    variant="outline"
                    size="sm"
                    phx-click="new_search"
                  >
                    Nueva búsqueda
                  </.button>
                </:action>
              </.card_header>

              <.card_content>
                <.form
                  for={@search_form}
                  id="persona-search-form"
                  phx-change="validate_search"
                  phx-submit="search"
                  class="flex flex-col gap-4"
                >
                  <div class="grid gap-4 sm:grid-cols-2">
                    <.field
                      field={@search_form[:document_type]}
                      type="select"
                      label="Tipo de documento"
                      options={@doc_options}
                      required
                      no_margin
                    />
                    <.field
                      field={@search_form[:document_number]}
                      type="text"
                      phx-debounce="300"
                      inputmode={
                        if @search_form[:document_type].value in [nil, "", "dni"],
                          do: "numeric",
                          else: "text"
                      }
                      label="Número de documento"
                      placeholder="Ej. 38123456"
                      required
                      no_margin
                    />
                  </div>
                  <div>
                    <.button type="submit" color="primary" phx-disable-with="Buscando...">Buscar</.button>
                  </div>
                </.form>
              </.card_content>
            </.card>
          </section>

          <section
            :if={@search_result == :not_found}
            id="persona-registration-section"
            aria-labelledby="persona-registration-heading"
          >
            <.card variant="basic">
              <.card_header>
                <.h2 id="persona-registration-heading" no_margin>Registrar persona</.h2>

                <.text_muted>
                  No encontramos una persona con el documento indicado. Completá los datos mínimos para registrarla.
                </.text_muted>
              </.card_header>

              <.card_content class="flex flex-col gap-4">
                <.alert
                  :if={@registration_error}
                  id="registration-error"
                  color="danger"
                  variant="callout"
                  with_icon
                >
                  <strong>No se pudo registrar la persona.</strong>
                  Revisá los datos ingresados e intentá nuevamente.
                </.alert>

                <.form
                  for={@registration_form}
                  id="assisted-registration-form"
                  phx-change="validate_registration"
                  phx-submit="register"
                  class="flex flex-col gap-4"
                >
                  <input
                    type="hidden"
                    name={@registration_form[:document_type].name}
                    value={@registration_form[:document_type].value}
                  />
                  <input
                    type="hidden"
                    name={@registration_form[:document_number].name}
                    value={@registration_form[:document_number].value}
                  />

                  <p class="text-sm text-gray-600">
                    Documento a registrar: <strong>{@registration_document}</strong>
                  </p>

                  <div class="grid gap-4 sm:grid-cols-2">
                    <.field
                      field={@registration_form[:first_name]}
                      type="text"
                      phx-debounce="300"
                      label="Nombres"
                      placeholder="Ej. Juan Manuel"
                      required
                      no_margin
                    />
                    <.field
                      field={@registration_form[:last_name]}
                      type="text"
                      phx-debounce="300"
                      label="Apellidos"
                      placeholder="Ej. Pérez"
                      required
                      no_margin
                    />
                    <.field
                      field={@registration_form[:birthdate]}
                      type="date"
                      phx-debounce="300"
                      label="Fecha de nacimiento"
                      required
                      no_margin
                    />
                    <.field
                      field={@registration_form[:phone]}
                      type="tel"
                      phx-debounce="300"
                      label="Teléfono"
                      placeholder="Ej. +5491122334455"
                      required
                      no_margin
                    />
                  </div>

                  <.field
                    field={@registration_form[:gender]}
                    type="select"
                    label="Género"
                    options={@gender_options}
                    prompt="Seleccionar género"
                    required
                    no_margin
                  />

                  <div>
                    <.button type="submit" color="primary" phx-disable-with="Registrando...">Registrar persona</.button>
                  </div>
                </.form>
              </.card_content>
            </.card>
          </section>

          <section
            :if={is_map(@search_result)}
            id="patient-summary-section"
            aria-labelledby="patient-summary-heading"
          >
            <.card variant="basic">
              <.card_header>
                <.h2 id="patient-summary-heading" no_margin>Resumen del paciente</.h2>
              </.card_header>

              <.card_content class="flex flex-col gap-4">
                <.alert
                  :if={@registration_outcome}
                  id="registration-outcome"
                  color="success"
                  variant="callout"
                  with_icon
                >
                  {outcome_feedback(@registration_outcome)}
                </.alert>

                <dl
                  id="patient-summary"
                  class="grid gap-x-4 gap-y-3 text-sm sm:grid-cols-[12rem_1fr] sm:items-baseline"
                >
                  <dt class="font-medium">Documento</dt>
                  <dd id="patient-summary-document" class="font-semibold">
                    {doc_label(@search_result.persona.document_type)} {@search_result.persona.document_number}
                  </dd>

                  <dt class="font-medium">Nombre completo</dt>
                  <dd id="patient-summary-full-name" class="font-semibold">
                    {@search_result.persona.first_name} {@search_result.persona.last_name}
                  </dd>

                  <dt class="font-medium">Estado del perfil</dt>
                  <dd id="patient-summary-profile-state">
                    {profile_state_label(@search_result.profile && @search_result.profile.state)}
                  </dd>

                  <dt class="font-medium">Teléfono</dt>
                  <dd id="patient-summary-phone">
                    {(@search_result.profile && @search_result.profile.phone) || "—"}
                  </dd>

                  <dt class="font-medium">Verificación telefónica</dt>
                  <dd id="patient-summary-phone-verified">
                    <.badge
                      :if={@search_result.profile && @search_result.profile.phone_verified}
                      color="success"
                      variant="soft"
                      size="sm"
                      dot
                      label="Teléfono verificado"
                      role="status"
                    />
                    <.badge
                      :if={
                        is_nil(@search_result.profile) or not @search_result.profile.phone_verified
                      }
                      color="gray"
                      variant="soft"
                      size="sm"
                      dot
                      label="Teléfono no verificado"
                      role="status"
                    />
                  </dd>
                </dl>

                <.alert
                  :if={@assisted_booking_notice}
                  id="assisted-booking-notice"
                  color="info"
                  variant="callout"
                  with_icon
                >
                  La reserva asistida estará disponible próximamente.
                </.alert>

                <div class="flex flex-wrap gap-2">
                  <.button
                    id="start-assisted-booking"
                    color="primary"
                    phx-click="start_assisted_booking"
                  >
                    Iniciar Reserva Asistida
                  </.button>
                </div>
              </.card_content>
            </.card>
          </section>
        </div>
      </.container>
    </main>
    """
  end
end

defmodule OrigenWeb.ProfessionalProfileLive do
  use OrigenWeb, :live_view

  on_mount {OrigenWeb.InternalAuthLive, :ensure_professional}

  alias OrigenWeb.ProfessionalProfileForm

  @fields ProfessionalProfileForm.fields()

  @impl true
  def mount(_params, _session, socket) do
    principal = socket.assigns.current_internal_session

    {:ok,
     socket
     |> assign(
       page_title: "Perfil profesional",
       fields: @fields,
       loading: true,
       load_error: false,
       save_error: false,
       saved: false,
       editing: false,
       profile: %{},
       draft: %{},
       missing: []
     )
     |> start_async(:load_profile, fn ->
       ProfessionalProfileForm.context().get_own_profile(principal)
     end)}
  end

  @impl true
  def handle_async(:load_profile, {:ok, {:ok, profile}}, socket) do
    profile = ProfessionalProfileForm.from_profile(profile)

    {:noreply,
     assign(socket,
       loading: false,
       profile: profile,
       draft: profile,
       missing: missing_fields(profile)
     )}
  end

  def handle_async(:load_profile, _failure, socket) do
    {:noreply, assign(socket, loading: false, load_error: true)}
  end

  @impl true
  def handle_event(_event, _params, %{assigns: %{loading: true}} = socket),
    do: {:noreply, socket}

  def handle_event(_event, _params, %{assigns: %{load_error: true}} = socket),
    do: {:noreply, socket}

  def handle_event("edit_profile", _params, socket) do
    {:noreply,
     assign(socket, editing: true, draft: socket.assigns.profile, saved: false, save_error: false)}
  end

  def handle_event(event, _params, %{assigns: %{editing: false}} = socket)
      when event in ["change_profile", "save_profile", "cancel_profile"],
      do: {:noreply, socket}

  def handle_event("change_profile", %{"profile" => params}, socket) when is_map(params) do
    {:noreply, assign(socket, draft: permitted_fields(params), saved: false, save_error: false)}
  end

  def handle_event("save_profile", %{"profile" => params}, socket) when is_map(params) do
    draft = permitted_fields(params)

    case ProfessionalProfileForm.context().save_own_profile(
           socket.assigns.current_internal_session,
           Map.take(params, Enum.map(@fields, &elem(&1, 0)))
         ) do
      {:ok, profile} ->
        profile = ProfessionalProfileForm.from_profile(profile)

        {:noreply,
         assign(socket,
           profile: profile,
           draft: profile,
           missing: missing_fields(profile),
           save_error: false,
           saved: true,
           editing: false
         )}

      {:error, _reason} ->
        {:noreply, assign(socket, draft: draft, save_error: true, saved: false)}
    end
  end

  def handle_event("cancel_profile", _params, socket) do
    {:noreply,
     assign(socket,
       draft: socket.assigns.profile,
       saved: false,
       save_error: false,
       editing: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main data-theme="light" class="min-h-screen bg-page py-6 text-text sm:py-10">
      <.container max_width="md">
        <div class="flex flex-col gap-6">
          <header class="flex flex-wrap items-start justify-between gap-4">
            <div class="space-y-2">
              <.h1 no_margin>Perfil profesional</.h1>
              <.text_muted>Los datos que identifican tu práctica profesional.</.text_muted>
            </div>
            <.button
              link_type="a"
              to="/configuracion/profesional"
              icon="hero-arrow-left"
              color="gray"
              variant="outline"
            >
              Volver a Ajustes
            </.button>
          </header>

          <div :if={@loading} id="profile-loading" role="status" aria-live="polite">
            Cargando perfil…
          </div>

          <.alert :if={@load_error} id="profile-load-error" color="danger" variant="callout" with_icon>
            <strong>No se pudo cargar el perfil.</strong>
            No se muestra información parcial.
            <:actions>
              <.button id="profile-retry" link_type="a" to="/configuracion/profesional/perfil">
                Reintentar carga
              </.button>
            </:actions>
          </.alert>

          <div :if={!@loading && !@load_error} class="flex flex-col gap-6">
            <.alert
              id="profile-status"
              color={if @missing == [], do: "success", else: "warning"}
              variant="callout"
              with_icon
            >
              <strong>{if @missing == [], do: "Perfil completo", else: "Perfil incompleto"}</strong>
              <p :if={@missing == []}>
                Los datos guardados cumplen los cinco requisitos del perfil.
                Tu cuenta activa aparece en el listado de pacientes.
                Esto no garantiza horarios disponibles.
              </p>
              <div :if={@missing != []}>
                <p>Para aparecer en el listado de reserva de pacientes, completá:</p>
                <ul id="profile-missing-fields" class="list-inside list-disc">
                  <li :for={{field, label} <- @missing} id={"profile-missing-" <> field}>{label}</li>
                </ul>
                <p>Podés guardar avances y seguir preparando tus ajustes.</p>
              </div>
            </.alert>

            <.alert :if={@saved} id="profile-save-success" color="success" variant="callout" with_icon>
              Cambios guardados.
            </.alert>

            <.alert
              :if={@save_error}
              id="profile-save-error"
              color="danger"
              variant="callout"
              with_icon
            >
              No se pudo guardar el perfil. Conservamos lo que escribiste; el estado del
              perfil sigue reflejando el último guardado exitoso.
            </.alert>

            <.card>
              <.card_header>
                <.h2 no_margin>Datos profesionales</.h2>
                <.text_muted>
                  Los cinco datos son obligatorios para completar el perfil, no para guardar avances.
                </.text_muted>
              </.card_header>
              <.card_content>
                <div :if={!@editing} id="profile-details" class="space-y-6">
                  <dl class="grid grid-cols-1 gap-6 sm:grid-cols-2">
                    <div :for={{field, label} <- @fields}>
                      <dt class="text-sm font-medium text-text">{label}</dt>
                      <dd id={"profile-read-" <> field} class="mt-1 break-words">
                        {if @profile[field] in [nil, ""], do: "Pendiente", else: @profile[field]}
                      </dd>
                    </div>
                  </dl>
                  <div class="flex justify-end">
                    <.button id="profile-edit" type="button" phx-click="edit_profile">
                      {if @missing == [], do: "Editar perfil", else: "Completar perfil"}
                    </.button>
                  </div>
                </div>
                <form
                  :if={@editing}
                  id="profile-form"
                  phx-change="change_profile"
                  phx-submit="save_profile"
                >
                  <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
                    <div
                      :for={{field, label} <- @fields}
                      class={if field == "specialty", do: "sm:col-span-2"}
                    >
                      <.field
                        type="text"
                        id={"profile-" <> field}
                        name={"profile[" <> field <> "]"}
                        label={label <> " · requerido para completar el perfil"}
                        value={@draft[field]}
                        aria-describedby={"profile-" <> field <> "-help"}
                        no_margin
                      />
                      <.text_small id={"profile-" <> field <> "-help"}>
                        {field_help(field, @draft[field])}
                      </.text_small>
                    </div>
                  </div>
                  <div class="flex flex-wrap justify-end gap-3">
                    <.button
                      id="profile-cancel"
                      type="button"
                      phx-click="cancel_profile"
                      color="gray"
                      variant="outline"
                    >
                      Cancelar
                    </.button>
                    <.button type="submit" phx-disable-with="Guardando…">
                      Guardar cambios
                    </.button>
                  </div>
                </form>
                <section
                  id="profile-photo"
                  class="my-6 space-y-2"
                  aria-labelledby="profile-photo-heading"
                >
                  <.h3 id="profile-photo-heading" no_margin>Foto · opcional</.h3>
                  <.text_muted>
                    No es necesaria para completar el perfil ni para reservar. La carga de fotos
                    todavía no está disponible: su almacenamiento y exposición están pendientes.
                  </.text_muted>
                </section>
              </.card_content>
            </.card>
          </div>
        </div>
      </.container>
    </main>
    """
  end

  defp permitted_fields(params) do
    Map.new(@fields, fn {field, _label} ->
      value = Map.get(params, field, "")
      {field, if(is_binary(value), do: String.trim(value), else: "")}
    end)
  end

  defp missing_fields(profile),
    do: ProfessionalProfileForm.missing_fields(profile)

  defp field_help(field, value) do
    cond do
      String.trim(value || "") == "" ->
        "Falta este dato para completar el perfil. Podés guardarlo vacío."

      field in ["license_type", "license_number"] ->
        "Texto libre. No se verifica la credencial ni se usa un catálogo."

      true ->
        "Dato declarado por el Profesional."
    end
  end
end

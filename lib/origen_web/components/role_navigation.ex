defmodule OrigenWeb.RoleNavigation do
  @moduledoc """
  Shared navigation for implemented role screens. Planned destinations only display
  a local notice; menu visibility never replaces the existing route authorization.
  """
  use OrigenWeb, :html

  attr :role, :atom, required: true, values: [:patient, :professional, :secretary, :administrator]
  attr :active, :string, default: nil
  attr :patient_profile, :map, default: nil
  attr :professional_identity, :map, default: nil
  attr :secretary_identity, :map, default: nil

  def navbar(assigns) do
    assigns =
      assigns
      |> assign(:items, items(assigns.role))
      |> assign(:patient_name, patient_name(assigns.patient_profile))
      |> assign(:professional_name, professional_name(assigns.professional_identity))
      |> assign(:account_name, account_name(assigns))
      |> assign(:account_role, account_role(assigns.role))

    ~H"""
    <header
      id="role-navigation"
      data-role={@role}
      data-theme="light"
      class="sticky top-0 z-40 bg-primary-700 text-white shadow-sm"
    >
      <div class="mx-auto flex max-w-7xl flex-wrap items-center gap-4 px-4 py-3 sm:px-6 lg:px-8">
        <div class="mr-auto flex items-center gap-3">
          <img src={~p"/images/origen-logo-dark.png"} alt="Origen" width="48" height="47" />
          <span class="text-lg font-semibold">Origen</span>
        </div>
        <nav aria-label="Navegación principal" class="flex flex-wrap items-center gap-2">
          <%= for {id, label, path} <- @items do %>
            <.button
              :if={path}
              id={"nav-#{id}"}
              link_type="a"
              to={path}
              color="white"
              variant={if @active == id, do: "solid", else: "ghost"}
              size="sm"
              aria-current={if @active == id, do: "page"}
            >
              {label}
            </.button>
            <.button
              :if={is_nil(path)}
              id={"nav-#{id}"}
              type="button"
              color="white"
              variant="ghost"
              size="sm"
              aria-controls="navigation-future-notice"
              phx-click={
                JS.remove_attribute("hidden", to: "#navigation-future-notice")
                |> JS.show(to: "#navigation-future-notice")
              }
            >
              {label}
            </.button>
          <% end %>
        </nav>
        <.dropdown
          id="navigation-account-menu"
          options_container_id="navigation-account-options"
          menu_items_wrapper_class="text-black"
          trigger_class="pc-button pc-button--white pc-button--sm"
          side="bottom"
          align="end"
        >
          <:trigger_element>
            <%= if @role in [:patient, :professional, :secretary] do %>
              <.avatar id={"navigation-#{@role}-avatar"} name={@account_name} size="sm" />
              <span class="text-left">
                <span class="block">{@account_name}</span>
                <span id={"navigation-#{@role}-role"} class="block text-xs">{@account_role}</span>
              </span>
            <% else %>
              Mi cuenta
            <% end %>
            <.icon name="hero-chevron-down-mini" class="size-4" />
          </:trigger_element>
          <div :if={@role == :patient && @patient_profile} class="space-y-1 px-4 py-2">
            <p id="navigation-patient-name" class="font-semibold">{@patient_name}</p>
            <p id="navigation-patient-email" class="break-all text-sm">{@patient_profile.email}</p>
          </div>
          <div :if={@role == :professional} class="space-y-1 px-4 py-2">
            <p id="navigation-professional-name" class="font-semibold">{@professional_name}</p>
            <p
              :if={@professional_identity && @professional_identity[:email]}
              id="navigation-professional-email"
              class="break-all text-sm"
            >
              {@professional_identity.email}
            </p>
          </div>
          <div :if={@role == :secretary} class="space-y-1 px-4 py-2">
            <p id="navigation-secretary-name" class="font-semibold">Secretaría</p>
            <p
              :if={@secretary_identity && @secretary_identity[:email]}
              id="navigation-secretary-email"
              class="break-all text-sm"
            >
              {@secretary_identity.email}
            </p>
          </div>
          <form
            action={if @role == :patient, do: ~p"/paciente/cerrar-sesion", else: ~p"/logout"}
            method="post"
            class="px-2 py-1"
          >
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <.button type="submit" color="gray" variant="ghost" size="sm" class="text-black">
              Cerrar sesión
            </.button>
          </form>
        </.dropdown>
      </div>
      <div id="navigation-future-notice" hidden class="mx-auto max-w-7xl px-4 pb-3 sm:px-6 lg:px-8">
        <.alert color="info" variant="callout" heading="Próximo en implementar">
          Esta sección estará disponible en una próxima versión.
          <:actions>
            <.button
              type="button"
              color="info"
              variant="ghost"
              size="sm"
              phx-click={
                JS.hide(to: "#navigation-future-notice")
                |> JS.set_attribute({"hidden", ""}, to: "#navigation-future-notice")
              }
            >
              Cerrar aviso
            </.button>
          </:actions>
        </.alert>
      </div>
    </header>
    """
  end

  defp account_name(%{role: :patient, patient_profile: profile}), do: patient_name(profile)

  defp account_name(%{role: :professional, professional_identity: identity}),
    do: professional_name(identity)

  defp account_name(%{role: :secretary}), do: "Secretaría"
  defp account_name(_), do: "Mi cuenta"

  defp account_role(:patient), do: "Paciente"
  defp account_role(:professional), do: "Profesional"
  defp account_role(:secretary), do: "Secretaría"
  defp account_role(_), do: nil

  defp patient_name(%{persona: %{first_name: first_name, last_name: last_name}}) do
    [first_name, last_name]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> "Paciente"
      name -> name
    end
  end

  defp patient_name(_), do: "Paciente"

  defp professional_name(identity) when is_map(identity) do
    [identity[:first_name], identity[:last_name]]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> "Profesional"
      name -> name
    end
  end

  defp professional_name(_), do: "Profesional"

  defp items(:patient) do
    [
      {"turns", "Mis turnos", ~p"/paciente/turnos"},
      {"book", "Reservar turno", ~p"/paciente/turnos/reservar"}
    ]
  end

  defp items(:professional) do
    [
      {"agenda", "Agenda", ~p"/profesional/agenda"},
      {"requests", "Solicitudes", nil},
      {"summary", "Resumen económico", nil},
      {"settings", "Ajustes", ~p"/profesional/ajustes"}
    ]
  end

  defp items(:secretary) do
    [
      {"agenda", "Agenda", ~p"/secretaria/agenda"},
      {"patients", "Pacientes", ~p"/secretaria/pacientes"},
      {"summary", "Resumen económico", nil}
    ]
  end

  defp items(:administrator), do: [{"accounts", "Cuentas", ~p"/administrador/cuentas"}]
end

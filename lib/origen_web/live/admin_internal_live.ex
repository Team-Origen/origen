defmodule OrigenWeb.AdminInternalLive do
  @moduledoc """
  LiveView for internal administration: create demo accounts.

  This is the first LiveView in the Origen project. It establishes
  patterns for authentication hooks, schemaless changesets, and
  PetalComponents integration.
  """

  use OrigenWeb, :live_view

  alias Ecto.Changeset

  @form_types %{
    role: :string,
    email: :string
  }

  @impl true
  def mount(_params, session, socket) do
    current_user = normalize_user(session["current_user"])

    current_user =
      if current_user == nil and Application.get_env(:origen, :env) == :dev,
        do: %{"id" => 0, "role" => "administrator"},
        else: current_user

    allowed_roles = allowed_roles_for(current_user)

    if allowed_roles == [] do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:form, to_form(new_changeset(), as: :form))
       |> assign(:result, nil)
       |> assign(:allowed_roles, allowed_roles)}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    changeset = build_changeset(params, socket.assigns.allowed_roles)
    {:noreply, assign(socket, :form, to_form(changeset, as: :form))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    changeset = build_changeset(params, socket.assigns.allowed_roles)

    if changeset.valid? do
      result = {:ok, %{email: changeset.changes.email, role: changeset.changes.role}}
      {:noreply, assign(socket, :form, to_form(changeset, as: :form)) |> assign(:result, result)}
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :form))}
    end
  end

  defp build_changeset(params, allowed_roles) do
    new_changeset()
    |> Changeset.cast(params, [:role, :email])
    |> Changeset.validate_required([:role, :email])
    |> Changeset.validate_inclusion(:role, Enum.map(allowed_roles, &to_string/1))
    |> Changeset.validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "must be a valid email address without spaces"
    )
    |> Map.put(:action, :validate)
  end

  defp new_changeset do
    {%{}, @form_types}
    |> Changeset.cast(%{}, [:role, :email])
  end

  defp normalize_user(%{"role" => role} = user) when is_binary(role), do: user
  defp normalize_user(%{"role" => role} = user), do: Map.put(user, "role", to_string(role))

  defp normalize_user(%{role: role} = user) when is_binary(role),
    do: %{"id" => user[:id], "role" => role}

  defp normalize_user(%{role: role} = user), do: %{"id" => user[:id], "role" => to_string(role)}
  defp normalize_user(user), do: user

  defp allowed_roles_for(%{"role" => "administrator"}), do: ["professional", "secretary"]
  defp allowed_roles_for(%{"role" => "secretary"}), do: ["secretary"]
  defp allowed_roles_for(_), do: []

  defp role_label("professional"), do: "Profesional"
  defp role_label("secretary"), do: "Secretaria"
  defp role_label(:professional), do: "Profesional"
  defp role_label(:secretary), do: "Secretaria"

  defp role_label_text("professional"), do: "Profesional"
  defp role_label_text("secretary"), do: "Secretaría"
  defp role_label_text(:professional), do: "Profesional"
  defp role_label_text(:secretary), do: "Secretaría"
  defp role_label_text(role), do: to_string(role)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full bg-white border border-[#E2E8F0] rounded-lg shadow-[0px_4px_12px_rgba(23,75,99,0.05)] p-8 font-inter">
        <div class="mb-8">
          <h1 class="text-2xl font-semibold text-gray-900 font-inter">Crear Cuenta Demo</h1>
          <p class="mt-2 text-sm text-gray-600 font-inter">
            Emitir una invitación para una cuenta nueva de profesional o secretaria
          </p>
        </div>

        <%!-- Result display --%>
        <div :if={@result} class="mb-6 p-4 rounded-lg border" role="status">
          <p :if={match?({:ok, _}, @result)} class="text-sm text-green-700 font-inter">
            Cuenta creada exitosamente para {elem(@result, 1).email} como {role_label_text(
              elem(@result, 1).role
            )}.
          </p>
          <p :if={match?({:error, _}, @result)} class="text-sm text-red-600 font-inter" role="alert">
            {error_message(elem(@result, 1))}
          </p>
        </div>

        <%!-- Form --%>
        <.form
          for={@form}
          id="admin-internal-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <.field
            field={@form[:role]}
            type="select"
            label="Rol"
            options={Enum.map(@allowed_roles, fn role -> {role_label(role), role} end)}
            prompt="Seleccionar rol"
            required
            class="py-[12px] px-[16px] rounded-md w-full border border-gray-300 text-[#1a1c1e] focus:ring-2 focus:ring-[#174B63] focus:border-[#174B63] font-inter"
            label_class="block text-[13px] font-semibold leading-[18px] tracking-[0.05em] text-gray-700 font-inter mb-1"
          />

          <.field
            field={@form[:email]}
            type="email"
            label="Correo electrónico"
            placeholder="demo@example.com"
            required
            autocomplete="email"
            class="py-[12px] px-[16px] rounded-md w-full border border-gray-300 text-[#1a1c1e] focus:ring-2 focus:ring-[#174B63] focus:border-[#174B63] font-inter"
            label_class="block text-[13px] font-semibold leading-[18px] tracking-[0.05em] text-gray-700 font-inter mb-1"
          />

          <.button
            type="submit"
            class="w-full bg-[#174B63] text-white h-[44px] px-6 rounded-md font-inter font-semibold hover:bg-[#143d52] focus:ring-2 focus:ring-[#174B63] focus:ring-offset-2"
          >
            Crear Cuenta
          </.button>
        </.form>
      </div>
    </div>
    """
  end

  defp error_message(:unauthorized), do: "No tiene permiso para realizar esta acción"
  defp error_message(:email_taken), do: "Ya existe una cuenta con este correo electrónico"

  defp error_message(:invalid_request),
    do: "Solicitud inválida. Por favor verifique los datos del formulario."

  defp error_message(_reason), do: "Ocurrió un error al procesar la solicitud"
end

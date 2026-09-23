defmodule OrigenWeb.AdminInternalLive do
  @moduledoc """
  LiveView for internal administration: create demo accounts.

  This is the first LiveView in the Origen project. It establishes
  patterns for authentication hooks, schemaless changesets, and
  PetalComponents integration.
  """

  use OrigenWeb, :live_view

  alias Ecto.Changeset
  alias Origen.Accounts

  @form_types %{
    role: :string,
    email: :string
  }

  @impl true
  def mount(_params, session, socket) do
    current_user = normalize_user(session["current_user"] || session[:current_user])

    current_user =
      if current_user == nil and Application.get_env(:origen, :env) == :dev do
        ensure_dev_admin()
      else
        current_user
      end

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
      result =
        create_account(
          socket.assigns.current_user,
          changeset.changes.role,
          changeset.changes.email
        )

      {:noreply, assign(socket, :form, to_form(changeset, as: :form)) |> assign(:result, result)}
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :form))}
    end
  end

  defp create_account(current_user, role, email) do
    with actor_id when is_integer(actor_id) <- get_actor_id(current_user),
         {:ok, role_atom} <- parse_role(role) do
      verifier_key = Application.get_env(:origen, :bootstrap_admin_verifier_key)
      opts = if verifier_key, do: [verifier_key: verifier_key], else: []

      case Accounts.create_and_invite_internal_account(
             actor_id,
             %{email: email, role: role_atom},
             opts
           ) do
        {:ok, invitation} ->
          {:ok,
           %{
             email: email,
             role: role,
             invitation_id: invitation.invitation_id,
             token: invitation.token
           }}

        {:error, :invalid_request} ->
          {:error, :email_taken}

        {:error, reason} ->
          {:error, reason}
      end
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp get_actor_id(%{"id" => id}) when is_integer(id), do: id

  defp get_actor_id(%{"id" => id}) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp get_actor_id(%{id: id}) when is_integer(id), do: id

  defp get_actor_id(%{id: id}) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp get_actor_id(_), do: nil

  defp parse_role("professional"), do: {:ok, :professional}
  defp parse_role("secretary"), do: {:ok, :secretary}
  defp parse_role(:professional), do: {:ok, :professional}
  defp parse_role(:secretary), do: {:ok, :secretary}
  defp parse_role(_), do: {:error, :invalid_role}

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
  defp role_label_text("secretary"), do: "Secretaria"
  defp role_label_text(:professional), do: "Profesional"
  defp role_label_text(:secretary), do: "Secretaria"
  defp role_label_text(role), do: to_string(role)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md lg:max-w-3xl xl:max-w-4xl w-full bg-white border border-[#E2E8F0] rounded-lg shadow-[0px_4px_12px_rgba(23,75,99,0.05)] p-8 lg:p-14 font-inter">
        <div class="mb-8">
          <h1 class="text-2xl lg:text-4xl font-semibold text-gray-900 font-inter">Crear Cuenta</h1>

          <p class="mt-2 text-sm lg:text-lg text-gray-600 font-inter">
            Emitir una invitación para una cuenta nueva de profesional o secretaria
          </p>
        </div>
        <%!-- Result display --%>
        <div :if={@result} class="mb-6 p-4 rounded-lg border" role="status">
          <p :if={match?({:ok, _}, @result)} class="text-sm text-green-700 font-inter">
            Invitación creada para {elem(@result, 1).email} como {role_label_text(
              elem(@result, 1).role
            )}. ID: {elem(@result, 1).invitation_id}, Token: {elem(@result, 1).token}
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
          class="space-y-6 lg:space-y-8"
        >
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8">
            <.field
              field={@form[:role]}
              type="select"
              label="Rol"
              options={Enum.map(@allowed_roles, fn role -> {role_label(role), role} end)}
              prompt="Seleccionar rol"
              required
              class="py-[20px] px-[16px] lg:py-[16px] lg:px-[20px] lg:text-lg rounded-md w-full border border-gray-300 text-[#1a1c1e] focus:ring-2 focus:ring-[#174B63] focus:border-[#174B63] font-inter"
              label_class="block text-[13px] lg:text-base font-semibold leading-[24px] tracking-[0.05em] text-gray-700 font-inter mb-1"
            />
            <.field
              field={@form[:email]}
              type="email"
              label="Correo electrónico"
              placeholder="demo@example.com"
              required
              autocomplete="email"
              class="py-[20px] px-[16px] lg:py-[16px] lg:px-[20px] lg:text-lg rounded-md w-full border border-gray-300 text-[#1a1c1e] focus:ring-2 focus:ring-[#174B63] focus:border-[#174B63] font-inter"
              label_class="block text-[13px] lg:text-base font-semibold leading-[24px] tracking-[0.05em] text-gray-700 font-inter mb-1"
            />
          </div>

          <.button
            type="submit"
            class="w-full bg-[#174B63] text-white h-[44px] lg:h-[52px] lg:text-lg px-6 rounded-md font-inter font-semibold hover:bg-[#143d52] focus:ring-2 focus:ring-[#174B63] focus:ring-offset-2"
          >
            Crear Cuenta
          </.button>
        </.form>
      </div>
    </div>
    """
  end

  defp ensure_dev_admin do
    case Origen.Repo.query(
           "SELECT id, role FROM internal_accounts WHERE role = 'administrator' AND state = 'active' ORDER BY id ASC LIMIT 1"
         ) do
      {:ok, %{rows: [[id, role]]}} ->
        %{"id" => id, "role" => role}

      _ ->
        case Origen.Repo.query("""
             INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
             VALUES ('admin@clinicaorigen.com', 'administrator', 'active', 'dev_hash', 'dev_secret', clock_timestamp())
             ON CONFLICT (lower(email)) DO UPDATE SET state = 'active'
             RETURNING id, role
             """) do
          {:ok, %{rows: [[id, role]]}} -> %{"id" => id, "role" => role}
          _ -> %{"id" => 0, "role" => "administrator"}
        end
    end
  rescue
    _ -> %{"id" => 0, "role" => "administrator"}
  end

  defp error_message(:unauthorized), do: "No tiene permiso para realizar esta acción"
  defp error_message(:email_taken), do: "Ya existe una cuenta con este correo electrónico"
  defp error_message(:invalid_role), do: "Rol inválido"

  defp error_message(:invalid_request),
    do: "Solicitud inválida. Por favor verifique los datos del formulario."

  defp error_message(_reason), do: "Ocurrió un error al procesar la solicitud"
end

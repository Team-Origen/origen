defmodule OrigenWeb.AdminInternalLive do
  @moduledoc """
  LiveView for internal staff account lifecycle administration (`/administrador/cuentas`).

  Allows an active Administrator to list, create (with invitation), reissue pending invitations,
  edit account email, deactivate, and reactivate only `professional` and `secretary` accounts,
  strictly without operational authority over patients, appointments, agendas, payments, or
  professional settings.
  """

  use OrigenWeb, :live_view

  alias Ecto.Changeset
  alias Origen.Accounts

  @form_types %{
    role: :string,
    email: :string
  }

  @edit_form_types %{
    email: :string
  }

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @impl true
  def mount(_params, session, socket) do
    resolved_user = resolve_session_user(session)

    current_user =
      resolved_user || normalize_user(session["current_user"] || session[:current_user])

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
      actor_id = get_actor_id(current_user)

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:form, to_form(new_changeset(), as: :form))
       |> assign(:result, nil)
       |> assign(:allowed_roles, allowed_roles)
       |> assign(:accounts, load_accounts(actor_id))
       |> assign(:editing_account_id, nil)
       |> assign(:edit_form, nil)
       |> assign(:edit_error, nil)
       |> assign(:lifecycle_feedback, nil)}
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

      actor_id = get_actor_id(socket.assigns.current_user)

      {:noreply,
       socket
       |> assign(:form, to_form(changeset, as: :form))
       |> assign(:result, result)
       |> assign(:accounts, load_accounts(actor_id))}
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :form))}
    end
  end

  @impl true
  def handle_event("reissue_invitation", %{"id" => id_param}, socket) do
    with actor_id when is_integer(actor_id) <- get_actor_id(socket.assigns.current_user),
         {:ok, target_id} <- parse_id(id_param) do
      verifier_key = resolve_verifier_key()
      opts = if verifier_key, do: [verifier_key: verifier_key], else: []

      case invoke_reissue(actor_id, target_id, opts) do
        {:ok, invitation} ->
          email =
            get_in(invitation, [:account, :email]) ||
              find_account_email(socket.assigns.accounts, target_id)

          {:noreply,
           socket
           |> assign(:accounts, load_accounts(actor_id))
           |> assign(
             :lifecycle_feedback,
             {:ok,
              "Invitación reemitida para #{email}. ID: #{invitation.invitation_id}, Token: #{invitation.token}"}
           )}

        {:error, reason} ->
          {:noreply, assign(socket, :lifecycle_feedback, {:error, error_message(reason)})}
      end
    else
      _ ->
        {:noreply, assign(socket, :lifecycle_feedback, {:error, error_message(:unauthorized)})}
    end
  end

  @impl true
  def handle_event("open_edit_account", %{"id" => id_param}, socket) do
    with {:ok, target_id} <- parse_id(id_param),
         %{id: ^target_id, email: email} <-
           Enum.find(socket.assigns.accounts, &(&1.id == target_id)) do
      edit_changeset = build_edit_changeset(%{"email" => email || ""})

      {:noreply,
       socket
       |> assign(:editing_account_id, target_id)
       |> assign(:edit_form, to_form(edit_changeset, as: :edit_account))
       |> assign(:edit_error, nil)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit_account", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_account_id, nil)
     |> assign(:edit_form, nil)
     |> assign(:edit_error, nil)}
  end

  @impl true
  def handle_event("validate_edit_account", %{"edit_account" => params}, socket) do
    changeset =
      params
      |> build_edit_changeset()
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:edit_form, to_form(changeset, as: :edit_account))
     |> assign(:edit_error, nil)}
  end

  @impl true
  def handle_event("save_edit_account", %{"edit_account" => params}, socket) do
    target_id = socket.assigns.editing_account_id
    actor_id = get_actor_id(socket.assigns.current_user)
    raw_email = Map.get(params, "email", "")
    clean_email = String.trim(raw_email)

    cond do
      not is_integer(actor_id) or not is_integer(target_id) ->
        {:noreply, assign(socket, :edit_error, error_message(:unauthorized))}

      not Regex.match?(@email_regex, clean_email) ->
        changeset =
          params
          |> build_edit_changeset()
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(:edit_form, to_form(changeset, as: :edit_account))
         |> assign(:edit_error, error_message(:invalid_email))}

      true ->
        case invoke_update_account(actor_id, target_id, %{email: clean_email}) do
          {:ok, updated} ->
            updated_email = Map.get(updated, :email) || Map.get(updated, "email") || clean_email

            {:noreply,
             socket
             |> assign(:accounts, load_accounts(actor_id))
             |> assign(:editing_account_id, nil)
             |> assign(:edit_form, nil)
             |> assign(:edit_error, nil)
             |> assign(
               :lifecycle_feedback,
               {:ok,
                "Correo actualizado a #{updated_email}. Se conserva la identidad e historial de la cuenta."}
             )}

          {:error, reason} ->
            changeset =
              params
              |> build_edit_changeset()
              |> Map.put(:action, :validate)

            {:noreply,
             socket
             |> assign(:edit_form, to_form(changeset, as: :edit_account))
             |> assign(:edit_error, error_message(reason))}
        end
    end
  end

  @impl true
  def handle_event("deactivate_account", %{"id" => id_param}, socket) do
    with actor_id when is_integer(actor_id) <- get_actor_id(socket.assigns.current_user),
         {:ok, target_id} <- parse_id(id_param) do
      target_account = Enum.find(socket.assigns.accounts, &(&1.id == target_id))

      case invoke_deactivate_account(actor_id, target_id) do
        {:ok, outcome} ->
          email =
            extract_outcome_email(outcome) ||
              (target_account && target_account.email) ||
              "ID #{target_id}"

          role =
            extract_outcome_role(outcome) ||
              (target_account && target_account.role) ||
              "professional"

          affected_count = extract_affected_count(outcome)

          message =
            if to_string(role) == "professional" do
              "Cuenta desactivada para #{email}. Se revocó el acceso y se bloquearon nuevas reservas. " <>
                "Existen #{affected_count} turnos futuros afectados para seguimiento por Secretaría " <>
                "(los turnos y solicitudes existentes no se cancelaron automáticamente)."
            else
              "Cuenta desactivada para #{email}. Se revocaron las sesiones activas y el acceso inmediato (0 turnos futuros afectados)."
            end

          {:noreply,
           socket
           |> assign(:accounts, load_accounts(actor_id))
           |> assign(:lifecycle_feedback, {:ok, message})}

        {:error, reason} ->
          {:noreply, assign(socket, :lifecycle_feedback, {:error, error_message(reason)})}
      end
    else
      _ ->
        {:noreply, assign(socket, :lifecycle_feedback, {:error, error_message(:unauthorized)})}
    end
  end

  @impl true
  def handle_event("reactivate_account", %{"id" => id_param}, socket) do
    with actor_id when is_integer(actor_id) <- get_actor_id(socket.assigns.current_user),
         {:ok, target_id} <- parse_id(id_param) do
      target_account = Enum.find(socket.assigns.accounts, &(&1.id == target_id))

      case invoke_reactivate_account(actor_id, target_id) do
        {:ok, outcome} ->
          email =
            extract_outcome_email(outcome) ||
              (target_account && target_account.email) ||
              "ID #{target_id}"

          {:noreply,
           socket
           |> assign(:accounts, load_accounts(actor_id))
           |> assign(
             :lifecycle_feedback,
             {:ok,
              "Cuenta reactivada para #{email}. Se restableció el acceso; la reactivación no restaura turnos cancelados."}
           )}

        {:error, reason} ->
          {:noreply, assign(socket, :lifecycle_feedback, {:error, error_message(reason)})}
      end
    else
      _ ->
        {:noreply, assign(socket, :lifecycle_feedback, {:error, error_message(:unauthorized)})}
    end
  end

  defp accounts_context do
    context = Application.get_env(:origen, :admin_internal_accounts_context, Accounts)
    Code.ensure_loaded?(context)
    context
  end

  defp load_accounts(actor_id) when is_integer(actor_id) do
    context = accounts_context()

    result =
      cond do
        function_exported?(context, :list_internal_accounts, 1) ->
          context.list_internal_accounts(actor_id)

        function_exported?(context, :list_internal_accounts, 2) ->
          context.list_internal_accounts(actor_id, [])

        function_exported?(context, :list_staff_accounts, 1) ->
          context.list_staff_accounts(actor_id)

        function_exported?(context, :list_staff_accounts, 2) ->
          context.list_staff_accounts(actor_id, [])

        true ->
          Accounts.list_internal_accounts(actor_id)
      end

    case result do
      {:ok, accounts} when is_list(accounts) ->
        Enum.map(accounts, &normalize_account_row/1)

      accounts when is_list(accounts) ->
        Enum.map(accounts, &normalize_account_row/1)

      _ ->
        []
    end
  end

  defp load_accounts(_actor_id), do: []

  defp normalize_account_row(account) when is_map(account) do
    %{
      id: Map.get(account, :id) || Map.get(account, "id"),
      email: Map.get(account, :email) || Map.get(account, "email"),
      role: to_string(Map.get(account, :role) || Map.get(account, "role")),
      state: to_string(Map.get(account, :state) || Map.get(account, "state")),
      future_affected_appointments_count:
        Map.get(account, :future_affected_appointments_count) ||
          Map.get(account, "future_affected_appointments_count") || 0
    }
  end

  defp create_account(current_user, role, email) do
    with actor_id when is_integer(actor_id) <- get_actor_id(current_user),
         {:ok, role_atom} <- parse_role(role) do
      verifier_key = resolve_verifier_key()
      opts = if verifier_key, do: [verifier_key: verifier_key], else: []
      context = accounts_context()

      result =
        if function_exported?(context, :create_and_invite_internal_account, 3) do
          context.create_and_invite_internal_account(
            actor_id,
            %{email: email, role: role_atom},
            opts
          )
        else
          Accounts.create_and_invite_internal_account(
            actor_id,
            %{email: email, role: role_atom},
            opts
          )
        end

      case result do
        {:ok, invitation} ->
          {:ok,
           %{
             email: email,
             role: role,
             invitation_id: invitation.invitation_id,
             token: invitation.token,
             invitation_url:
               OrigenWeb.Endpoint.url() <>
                 ~p"/activar" <>
                 "#" <>
                 URI.encode_query(%{
                   "invitation_id" => invitation.invitation_id,
                   "token" => invitation.token
                 })
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

  defp invoke_reissue(actor_id, target_id, opts) do
    context = accounts_context()

    if function_exported?(context, :reissue_internal_invitation, 3) do
      context.reissue_internal_invitation(actor_id, target_id, opts)
    else
      Accounts.reissue_internal_invitation(actor_id, target_id, opts)
    end
  end

  defp invoke_update_account(actor_id, target_id, attrs) do
    context = accounts_context()

    cond do
      function_exported?(context, :update_internal_account, 3) ->
        context.update_internal_account(actor_id, target_id, attrs)

      function_exported?(context, :update_internal_account, 4) ->
        context.update_internal_account(actor_id, target_id, attrs, [])

      function_exported?(context, :update_staff_account_email, 3) ->
        context.update_staff_account_email(actor_id, target_id, attrs.email)

      true ->
        Accounts.update_internal_account(actor_id, target_id, attrs)
    end
  end

  defp invoke_deactivate_account(actor_id, target_id) do
    context = accounts_context()

    cond do
      function_exported?(context, :deactivate_internal_account, 2) ->
        context.deactivate_internal_account(actor_id, target_id)

      function_exported?(context, :deactivate_internal_account, 3) ->
        context.deactivate_internal_account(actor_id, target_id, [])

      true ->
        Accounts.deactivate_internal_account(actor_id, target_id)
    end
  end

  defp invoke_reactivate_account(actor_id, target_id) do
    context = accounts_context()

    cond do
      function_exported?(context, :reactivate_internal_account, 2) ->
        context.reactivate_internal_account(actor_id, target_id)

      function_exported?(context, :reactivate_internal_account, 3) ->
        context.reactivate_internal_account(actor_id, target_id, [])

      true ->
        Accounts.reactivate_internal_account(actor_id, target_id)
    end
  end

  defp extract_outcome_email(%{account: %{email: email}}) when is_binary(email), do: email
  defp extract_outcome_email(%{email: email}) when is_binary(email), do: email
  defp extract_outcome_email(_), do: nil

  defp extract_outcome_role(%{account: %{role: role}}) when not is_nil(role), do: role
  defp extract_outcome_role(%{role: role}) when not is_nil(role), do: role
  defp extract_outcome_role(_), do: nil

  defp extract_affected_count(%{future_affected_appointments_count: count})
       when is_integer(count),
       do: count

  defp extract_affected_count(%{account: %{future_affected_appointments_count: count}})
       when is_integer(count),
       do: count

  defp extract_affected_count(_), do: 0

  defp find_account_email(accounts, target_id) do
    case Enum.find(accounts, &(&1.id == target_id)) do
      %{email: email} when is_binary(email) -> email
      _ -> "ID #{target_id}"
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}

  defp resolve_verifier_key do
    case Application.get_env(:origen, :bootstrap_admin_verifier_key) do
      k when is_binary(k) and byte_size(k) >= 32 ->
        k

      _ ->
        if Application.get_env(:origen, :env) in [:dev, :test] do
          String.duplicate("k", 32)
        else
          nil
        end
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
    |> Changeset.validate_format(:email, @email_regex,
      message: "must be a valid email address without spaces"
    )
    |> Map.put(:action, :validate)
  end

  defp new_changeset do
    {%{}, @form_types}
    |> Changeset.cast(%{}, [:role, :email])
  end

  defp build_edit_changeset(params) do
    {%{}, @edit_form_types}
    |> Changeset.cast(params, [:email])
    |> Changeset.validate_required([:email])
    |> Changeset.validate_format(:email, @email_regex,
      message: "El formato del correo electrónico no es válido"
    )
  end

  defp resolve_session_user(session) when is_map(session) do
    token = session["internal_session_token"] || session[:internal_session_token]

    with token when is_binary(token) <- token,
         {:ok, internal_session} <- Origen.Sessions.touch_session(token) do
      %{
        "id" => internal_session.account_id,
        "role" => to_string(internal_session.role),
        "state" => "active"
      }
    else
      _ -> nil
    end
  end

  defp resolve_session_user(_session), do: nil

  defp normalize_user(%{"role" => role} = user) do
    state = Map.get(user, "state") || Map.get(user, :state) || "active"

    user
    |> Map.put("role", to_string(role))
    |> Map.put("state", to_string(state))
  end

  defp normalize_user(%{role: role} = user) do
    state = Map.get(user, :state) || Map.get(user, "state") || "active"

    %{
      "id" => user[:id] || user["id"],
      "role" => to_string(role),
      "state" => to_string(state)
    }
  end

  defp normalize_user(user), do: user

  defp allowed_roles_for(%{"role" => "administrator", "state" => "active"}),
    do: ["professional", "secretary"]

  defp allowed_roles_for(%{"role" => "administrator"} = user) do
    if Map.get(user, "state", "active") == "active" do
      ["professional", "secretary"]
    else
      []
    end
  end

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

  defp state_label("active"), do: "Activa"
  defp state_label("pending_activation"), do: "Pendiente de activación"
  defp state_label("deactivated"), do: "Desactivada"
  defp state_label(other), do: to_string(other)

  defp state_badge_classes("active"),
    do: "bg-green-100 text-green-800 border-green-200"

  defp state_badge_classes("pending_activation"),
    do: "bg-amber-100 text-amber-800 border-amber-200"

  defp state_badge_classes("deactivated"),
    do: "bg-gray-100 text-gray-800 border-gray-300"

  defp state_badge_classes(_),
    do: "bg-gray-100 text-gray-800 border-gray-200"

  @impl true
  def render(assigns) do
    ~H"""
    <OrigenWeb.RoleNavigation.navbar role={:administrator} active="accounts" />
    <div class="min-h-screen flex flex-col items-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8 gap-8">
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
            )}. ID: {elem(@result, 1).invitation_id}
          </p>

          <div
            :if={match?({:ok, _}, @result)}
            id="created-invitation"
            phx-hook=".InvitationCopy"
            class="mt-3 space-y-3"
          >
            <label for="created-invitation-url" class="block text-sm font-medium text-gray-700">
              Enlace de invitación
            </label>
            <input
              id="created-invitation-url"
              type="text"
              value={elem(@result, 1).invitation_url}
              readonly
              autocomplete="off"
              spellcheck="false"
              aria-describedby="created-invitation-help"
              class="w-full min-w-0 rounded-md border border-gray-300 p-2 text-sm text-black focus:ring-2 focus:ring-[#174B63]"
            />
            <p id="created-invitation-help" class="text-sm text-gray-600">
              Compartí este enlace solo con la persona invitada. Conserva su vencimiento y uso único.
              Por seguridad, no se mostrará al recargar esta página.
            </p>
            <div class="flex flex-wrap items-center gap-3">
              <.button id="copy-created-invitation" type="button">
                Copiar enlace
              </.button>
              <.link
                id="created-invitation-link"
                href={elem(@result, 1).invitation_url}
                target="_blank"
                rel="noopener noreferrer"
                class="rounded-md px-2 py-2 text-sm text-[#174B63] underline underline-offset-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#174B63]"
              >
                Abrir invitación
              </.link>
            </div>
            <p
              id="invitation-copy-status"
              role="status"
              aria-live="polite"
              class="text-sm text-gray-700"
            >
            </p>
          </div>

          <script :type={Phoenix.LiveView.ColocatedHook} name=".InvitationCopy">
            export default {
              mounted() {
                this.copy = async () => {
                  const input = this.el.querySelector("#created-invitation-url");
                  const status = this.el.querySelector("#invitation-copy-status");
                  const value = input.value;
                  try {
                    await navigator.clipboard.writeText(value);
                    if (input.isConnected && input.value === value) {
                      status.textContent = "Enlace copiado.";
                    }
                  } catch (_) {
                    if (input.isConnected && input.value === value) {
                      input.focus();
                      input.select();
                      status.textContent = "No se pudo copiar automáticamente. Copiá el enlace seleccionado.";
                    }
                  }
                };
                this.el.querySelector("#copy-created-invitation").addEventListener("click", this.copy);
              },
              updated() {
                this.el.querySelector("#invitation-copy-status").textContent = "";
              },
              destroyed() {
                this.el.querySelector("#copy-created-invitation")?.removeEventListener("click", this.copy);
              }
            }
          </script>

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
            phx-disable-with="Creando Cuenta..."
            class="w-full bg-[#174B63] text-white h-[44px] lg:h-[52px] lg:text-lg px-6 rounded-md font-inter font-semibold hover:bg-[#143d52] focus:ring-2 focus:ring-[#174B63] focus:ring-offset-2"
          >
            Crear Cuenta
          </.button>
        </.form>
      </div>

      <%!-- Internal Accounts Lifecycle Management Section --%>
      <section
        id="internal-accounts-section"
        aria-labelledby="internal-accounts-heading"
        class="max-w-md lg:max-w-3xl xl:max-w-4xl w-full bg-white border border-[#E2E8F0] rounded-lg shadow-[0px_4px_12px_rgba(23,75,99,0.05)] p-8 lg:p-14 font-inter"
      >
        <div class="mb-6">
          <h2
            id="internal-accounts-heading"
            class="text-xl lg:text-2xl font-semibold text-gray-900 font-inter"
          >
            Cuentas internas de personal
          </h2>
          <p class="mt-1 text-sm text-gray-600 font-inter">
            Administración de cuentas de Profesional y Secretaría. No otorga acceso a agendas, pacientes, turnos, pagos ni ajustes profesionales.
          </p>
        </div>

        <div
          :if={@lifecycle_feedback}
          id="lifecycle-feedback"
          class={[
            "mb-6 p-4 rounded-lg border",
            if(match?({:ok, _}, @lifecycle_feedback),
              do: "bg-green-50 border-green-200 text-green-800",
              else: "bg-red-50 border-red-200 text-red-700"
            )
          ]}
          role={if match?({:ok, _}, @lifecycle_feedback), do: "status", else: "alert"}
        >
          <p class="text-sm font-inter">{elem(@lifecycle_feedback, 1)}</p>
        </div>

        <div id="internal-accounts-list" class="space-y-4">
          <p :if={@accounts == []} class="text-sm text-gray-500 font-inter">
            No hay cuentas internas de personal registradas.
          </p>

          <div
            :for={account <- @accounts}
            id={"account-row-#{account.id}"}
            class="p-4 border border-gray-200 rounded-lg flex flex-col gap-3"
          >
            <div class="flex flex-wrap items-center justify-between gap-4">
              <div class="space-y-1">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="font-semibold text-gray-900 font-inter">{account.email}</span>
                  <span class="text-xs font-medium px-2.5 py-0.5 rounded border bg-slate-100 text-slate-800 border-slate-200">
                    {role_label_text(account.role)}
                  </span>
                  <span class={[
                    "text-xs font-medium px-2.5 py-0.5 rounded border",
                    state_badge_classes(account.state)
                  ]}>
                    {state_label(account.state)}
                  </span>
                </div>

                <p
                  :if={account.role == "professional" and account.state == "deactivated"}
                  id={"account-affected-turns-#{account.id}"}
                  class="text-xs text-amber-800 font-inter"
                >
                  Seguimiento para Secretaría: {account.future_affected_appointments_count} turnos futuros afectados (no se cancelaron automáticamente).
                </p>
              </div>

              <div class="flex flex-wrap items-center gap-2">
                <.button
                  :if={@editing_account_id != account.id}
                  id={"open-edit-account-#{account.id}"}
                  type="button"
                  size="sm"
                  color="gray"
                  variant="outline"
                  phx-click="open_edit_account"
                  phx-value-id={account.id}
                >
                  Editar correo
                </.button>

                <.button
                  :if={account.state == "pending_activation"}
                  id={"reissue-invitation-#{account.id}"}
                  type="button"
                  size="sm"
                  color="secondary"
                  variant="outline"
                  phx-click="reissue_invitation"
                  phx-value-id={account.id}
                >
                  Reemitir invitación
                </.button>

                <.button
                  :if={account.state in ["active", "pending_activation"]}
                  id={"deactivate-account-#{account.id}"}
                  type="button"
                  size="sm"
                  color="danger"
                  variant="outline"
                  phx-click="deactivate_account"
                  phx-value-id={account.id}
                >
                  Desactivar
                </.button>

                <.button
                  :if={account.state == "deactivated"}
                  id={"reactivate-account-#{account.id}"}
                  type="button"
                  size="sm"
                  color="primary"
                  variant="outline"
                  phx-click="reactivate_account"
                  phx-value-id={account.id}
                >
                  Reactivar
                </.button>
              </div>
            </div>

            <div
              :if={@editing_account_id == account.id and @edit_form != nil}
              class="pt-3 border-t border-gray-100"
            >
              <p
                :if={@edit_error}
                id={"edit-account-error-#{account.id}"}
                class="mb-2 text-xs text-red-600 font-inter"
                role="alert"
              >
                {@edit_error}
              </p>

              <.form
                for={@edit_form}
                id={"edit-account-form-#{account.id}"}
                phx-change="validate_edit_account"
                phx-submit="save_edit_account"
                class="flex flex-wrap items-end gap-3"
              >
                <div class="flex-1 min-w-[240px]">
                  <.field
                    field={@edit_form[:email]}
                    type="email"
                    label="Nuevo correo electrónico"
                    required
                    no_margin
                  />
                </div>
                <div class="flex items-center gap-2">
                  <.button
                    id={"cancel-edit-account-#{account.id}"}
                    type="button"
                    size="sm"
                    color="gray"
                    variant="ghost"
                    phx-click="cancel_edit_account"
                  >
                    Cancelar
                  </.button>
                  <.button
                    id={"save-edit-account-#{account.id}"}
                    type="submit"
                    size="sm"
                    color="primary"
                  >
                    Guardar correo
                  </.button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp ensure_dev_admin do
    case Origen.Repo.query(
           "SELECT id, role FROM internal_accounts WHERE role = 'administrator' AND state = 'active' ORDER BY id ASC LIMIT 1"
         ) do
      {:ok, %{rows: [[id, role]]}} ->
        %{"id" => id, "role" => role, "state" => "active"}

      _ ->
        case Origen.Repo.query("""
             INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
             VALUES ('admin@clinicaorigen.com', 'administrator', 'active', 'dev_hash', 'dev_secret', clock_timestamp())
             ON CONFLICT (lower(email)) DO UPDATE SET state = 'active'
             RETURNING id, role
             """) do
          {:ok, %{rows: [[id, role]]}} -> %{"id" => id, "role" => role, "state" => "active"}
          _ -> %{"id" => 0, "role" => "administrator", "state" => "active"}
        end
    end
  rescue
    _ -> %{"id" => 0, "role" => "administrator", "state" => "active"}
  end

  defp error_message(:unauthorized), do: "No tiene permiso para realizar esta acción"
  defp error_message(:email_taken), do: "Ya existe una cuenta con este correo electrónico"
  defp error_message(:invalid_email), do: "El formato del correo electrónico no es válido"
  defp error_message(:invalid_role), do: "Rol inválido"

  defp error_message(:invalid_request),
    do: "Solicitud inválida. Por favor verifique los datos del formulario."

  defp error_message(_reason), do: "Ocurrió un error al procesar la solicitud"
end

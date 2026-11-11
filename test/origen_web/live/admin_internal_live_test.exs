defmodule OrigenWeb.AdminInternalLiveTest do
  @moduledoc """
  Tests for the AdminInternalLive LiveView.

  Tests cover:
  - Mount with current_user
  - Form validation (real-time)
  - Form submission (save)
  - Role-based access control
  """

  use OrigenWeb.LiveViewCase

  @default_verifier_key String.duplicate("k", 32)

  setup do
    previous_key = Application.get_env(:origen, :bootstrap_admin_verifier_key)
    Application.put_env(:origen, :bootstrap_admin_verifier_key, @default_verifier_key)

    on_exit(fn ->
      if previous_key do
        Application.put_env(:origen, :bootstrap_admin_verifier_key, previous_key)
      else
        Application.put_env(:origen, :bootstrap_admin_verifier_key, @default_verifier_key)
      end
    end)

    :ok
  end

  describe "mount/3" do
    test "renders the form with role and email fields", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/administrador/cuentas")

      assert html =~ "Crear Cuenta"
      assert html =~ "Rol"
      assert html =~ "Correo electrónico"
      assert html =~ "Crear Cuenta"
    end

    test "shows both professional and secretary options for administrator", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/administrador/cuentas")

      assert html =~ "Profesional"
      assert html =~ "Secretaria"
    end

    test "redirects away for secretary session without rendering the screen", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 2, role: :secretary})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "redirects away for secretary with real internal_session_token", %{conn: conn} do
      secretary = insert_active_account("secretary")
      {:ok, %{token: token}} = Origen.Sessions.create_session(secretary.id)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:internal_session_token, token)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "redirects away when administrator account is not active", %{conn: conn} do
      conn =
        put_user_in_session(conn, %{id: 1, role: :administrator, state: "pending_activation"})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "authenticates and mounts using real internal_session_token without synthetic current_user",
         %{conn: conn} do
      admin = insert_active_account("administrator")
      {:ok, %{token: token}} = Origen.Sessions.create_session(admin.id)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:internal_session_token, token)

      {:ok, _view, html} = live(conn, ~p"/administrador/cuentas")

      assert html =~ "Crear Cuenta"
      assert html =~ "Profesional"
      assert html =~ "Secretaria"
    end
  end

  describe "authorization" do
    test "redirects away without rendering the screen when there is no session", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "redirects away for a role that is neither administrator nor secretary", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 3, role: :professional})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "redirects away for a patient session", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 4, role: :patient})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end
  end

  describe "validate event" do
    test "shows validation error for invalid email", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_change()

      assert html =~ "must be a valid email address without spaces"
    end

    test "shows validation error for missing role", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "", email: "test@example.com"})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation error for missing email", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "clears validation errors when input is corrected", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_change()

      assert html =~ "must be a valid email address without spaces"

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "valid@example.com"})
        |> render_change()

      refute html =~ "must be a valid email address without spaces"
    end
  end

  describe "save event" do
    test "shows success result when administrator creates professional account", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "demo@example.com"})
        |> render_submit()

      assert html =~ "Invitación creada para"
      assert html =~ "demo@example.com"
      assert html =~ "Profesional"
    end

    test "creation presents the existing invitation with client-only copy and safe open controls",
         %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")
      refute has_element?(view, "#created-invitation-link")

      html =
        view
        |> form("#admin-internal-form",
          form: %{role: "professional", email: "invite@example.test"}
        )
        |> render_submit()

      document = LazyHTML.from_document(html)
      [url] = LazyHTML.query(document, "#created-invitation-url") |> LazyHTML.attribute("value")
      uri = URI.parse(url)
      assert uri.path == "/activar"
      assert is_nil(uri.query)
      assert uri.host == URI.parse(OrigenWeb.Endpoint.url()).host
      fragment = URI.decode_query(uri.fragment)
      assert Map.keys(fragment) |> Enum.sort() == ["invitation_id", "token"]
      {invitation_id, ""} = Integer.parse(fragment["invitation_id"])

      assert {:ok, binding} =
               Origen.Accounts.prepare_internal_account_activation(
                 invitation_id,
                 fragment["token"],
                 verifier_key: @default_verifier_key
               )

      assert has_element?(
               view,
               "#created-invitation-link[target='_blank'][rel='noopener noreferrer']",
               "Abrir invitación"
             )

      assert has_element?(view, "#copy-created-invitation[type='button']", "Copiar enlace")
      refute has_element?(view, "#copy-created-invitation[phx-click]")
      assert has_element?(view, "#created-invitation-url[readonly]")

      {:ok, before_accounts} = Origen.Accounts.list_internal_accounts(admin.id)
      render(view)
      {:ok, after_accounts} = Origen.Accounts.list_internal_accounts(admin.id)
      assert before_accounts == after_accounts
      assert Enum.count(after_accounts, &(&1.email == "invite@example.test")) == 1

      assert {:ok, ^binding} =
               Origen.Accounts.prepare_internal_account_activation(
                 invitation_id,
                 fragment["token"],
                 verifier_key: @default_verifier_key
               )

      {:ok, fresh_view, _html} = live(conn, ~p"/administrador/cuentas")
      refute has_element?(fresh_view, "#created-invitation-url")
    end

    test "shows success result when administrator creates secretary account", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "secretary", email: "secre@example.com"})
        |> render_submit()

      assert html =~ "Invitación creada para"
      assert html =~ "secre@example.com"
      assert html =~ "Secretaria"
    end

    test "shows validation errors on invalid submission", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "", email: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation error for invalid email on submission", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_submit()

      assert html =~ "must be a valid email address without spaces"
    end

    test "shows error when email already exists", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view
      |> form("#admin-internal-form",
        form: %{role: "professional", email: "duplicated@example.com"}
      )
      |> render_submit()

      html =
        view
        |> form("#admin-internal-form",
          form: %{role: "professional", email: "duplicated@example.com"}
        )
        |> render_submit()

      assert html =~ "Ya existe una cuenta con este correo electrónico"
    end

    test "secretary is denied and redirected before mounting or submitting", %{conn: conn} do
      secretary = insert_active_account("secretary")
      conn = put_user_in_session(conn, secretary)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "tampering with role to create administrator is rejected", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      # Client bypasses DOM and directly pushes event
      html =
        render_submit(view, :save, %{
          "form" => %{"role" => "administrator", "email" => "newadmin@example.com"}
        })

      assert html =~ "is invalid" or html =~ "Rol inválido"
    end

    test "typed values are preserved in the form inputs upon rejection", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      # First submission creates the account
      view
      |> form("#admin-internal-form",
        form: %{role: "professional", email: "first@example.com"}
      )
      |> render_submit()

      # Second submission with the same email fails (email taken)
      html =
        view
        |> form("#admin-internal-form",
          form: %{role: "professional", email: "first@example.com"}
        )
        |> render_submit()

      assert html =~ "Ya existe una cuenta con este correo electrónico"
      assert html =~ ~s(value="first@example.com")
    end
  end

  describe "internal accounts lifecycle (using explicit test double for #374 frontend isolation)" do
    defmodule FakeAccountsContext do
      @moduledoc """
      Explicit test double for #374 (`work:frontend`) to verify the AdminInternalLive UI
      against the #372 contract while #373 (`work:backend`) develops in parallel.
      Real domain integration is verified in #375 (`work:integration`).
      """

      defp agent_pid do
        Application.get_env(:origen, :fake_accounts_agent_pid)
      end

      def list_internal_accounts(actor_id) when is_integer(actor_id) do
        case agent_pid() do
          pid when is_pid(pid) ->
            {:ok, Agent.get(pid, & &1.accounts)}

          _ ->
            {:ok, []}
        end
      end

      def create_and_invite_internal_account(actor_id, attrs, opts) do
        case agent_pid() do
          nil ->
            Origen.Accounts.create_and_invite_internal_account(actor_id, attrs, opts)

          pid ->
            email = String.trim(attrs.email)

            Agent.get_and_update(pid, fn state ->
              if Enum.any?(state.accounts, &(String.downcase(&1.email) == String.downcase(email))) do
                {{:error, :email_taken}, state}
              else
                new_id = Enum.max(Enum.map(state.accounts, & &1.id), fn -> 100 end) + 1

                new_account = %{
                  id: new_id,
                  email: email,
                  role: Atom.to_string(attrs.role),
                  state: "pending_activation",
                  future_affected_appointments_count: 0
                }

                res =
                  {:ok,
                   %{
                     account: %{
                       id: new_id,
                       email: email,
                       role: attrs.role,
                       state: :pending_activation
                     },
                     account_id: new_id,
                     invitation_id: new_id + 500,
                     token: "tok_#{new_id}",
                     issued_at: DateTime.utc_now(),
                     expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
                   }}

                {res, %{state | accounts: state.accounts ++ [new_account]}}
              end
            end)
        end
      end

      def reissue_internal_invitation(actor_id, account_id, opts) do
        case agent_pid() do
          nil ->
            Origen.Accounts.reissue_internal_invitation(actor_id, account_id, opts)

          pid ->
            state = Agent.get(pid, & &1)

            case Enum.find(state.accounts, &(&1.id == account_id)) do
              %{state: "pending_activation"} = acc ->
                {:ok,
                 %{
                   account: %{
                     id: acc.id,
                     email: acc.email,
                     role: String.to_atom(acc.role),
                     state: :pending_activation
                   },
                   account_id: acc.id,
                   invitation_id: acc.id + 900,
                   token: "reissued_tok_#{acc.id}",
                   issued_at: DateTime.utc_now(),
                   expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
                 }}

              _ ->
                {:error, :unauthorized}
            end
        end
      end

      def update_internal_account(actor_id, target_id, attrs) when is_integer(actor_id) do
        pid = agent_pid()
        raw_email = Map.get(attrs, :email) || Map.get(attrs, "email") || ""
        clean_email = String.trim(raw_email)

        Agent.get_and_update(pid, fn state ->
          cond do
            not Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, clean_email) ->
              {{:error, :invalid_email}, state}

            Enum.any?(
              state.accounts,
              &(&1.id != target_id and String.downcase(&1.email) == String.downcase(clean_email))
            ) ->
              {{:error, :email_taken}, state}

            true ->
              case Enum.find(state.accounts, &(&1.id == target_id)) do
                nil ->
                  {{:error, :unauthorized}, state}

                %{role: "administrator"} ->
                  {{:error, :unauthorized}, state}

                target ->
                  updated = %{target | email: clean_email}

                  accounts =
                    Enum.map(state.accounts, fn acc ->
                      if acc.id == target_id, do: updated, else: acc
                    end)

                  {{:ok, updated}, %{state | accounts: accounts}}
              end
          end
        end)
      end

      def deactivate_internal_account(actor_id, target_id) when is_integer(actor_id) do
        pid = agent_pid()

        Agent.get_and_update(pid, fn state ->
          case Enum.find(state.accounts, &(&1.id == target_id)) do
            nil ->
              {{:error, :unauthorized}, state}

            %{role: "administrator"} ->
              {{:error, :unauthorized}, state}

            %{state: "deactivated"} ->
              {{:error, :invalid_request}, state}

            target ->
              affected_count =
                if target.role == "professional",
                  do: Map.get(target, :future_affected_appointments_count, 0),
                  else: 0

              had_credentials = Map.get(target, :had_credentials, target.state == "active")

              updated =
                target
                |> Map.put(:state, "deactivated")
                |> Map.put(:had_credentials, had_credentials)
                |> Map.put(:future_affected_appointments_count, affected_count)

              accounts =
                Enum.map(state.accounts, fn acc ->
                  if acc.id == target_id, do: updated, else: acc
                end)

              res =
                {:ok,
                 %{
                   account: updated,
                   future_affected_appointments_count: affected_count
                 }}

              {res, %{state | accounts: accounts}}
          end
        end)
      end

      def reactivate_internal_account(actor_id, target_id) when is_integer(actor_id) do
        pid = agent_pid()

        Agent.get_and_update(pid, fn state ->
          case Enum.find(state.accounts, &(&1.id == target_id)) do
            nil ->
              {{:error, :unauthorized}, state}

            %{role: "administrator"} ->
              {{:error, :unauthorized}, state}

            %{state: "deactivated"} = target ->
              restored_state =
                if Map.get(target, :had_credentials, true),
                  do: "active",
                  else: "pending_activation"

              updated = %{target | state: restored_state}

              accounts =
                Enum.map(state.accounts, fn acc ->
                  if acc.id == target_id, do: updated, else: acc
                end)

              {{:ok, %{account: updated}}, %{state | accounts: accounts}}

            _ ->
              {{:error, :invalid_request}, state}
          end
        end)
      end
    end

    setup do
      previous_adapter = Application.get_env(:origen, :admin_internal_accounts_context)

      initial_accounts = [
        %{
          id: 101,
          email: "dra.garcia@clinicaorigen.com",
          role: "professional",
          state: "active",
          had_credentials: true,
          future_affected_appointments_count: 3
        },
        %{
          id: 102,
          email: "dr.perez@clinicaorigen.com",
          role: "professional",
          state: "pending_activation",
          had_credentials: false,
          future_affected_appointments_count: 0
        },
        %{
          id: 103,
          email: "secretaria.ana@clinicaorigen.com",
          role: "secretary",
          state: "active",
          had_credentials: true,
          future_affected_appointments_count: 0
        },
        %{
          id: 104,
          email: "dr.baja@clinicaorigen.com",
          role: "professional",
          state: "deactivated",
          had_credentials: true,
          future_affected_appointments_count: 2
        }
      ]

      {:ok, agent} = start_supervised({Agent, fn -> %{accounts: initial_accounts} end})
      Application.put_env(:origen, :fake_accounts_agent_pid, agent)
      Application.put_env(:origen, :admin_internal_accounts_context, FakeAccountsContext)

      on_exit(fn ->
        Application.delete_env(:origen, :fake_accounts_agent_pid)

        if previous_adapter do
          Application.put_env(:origen, :admin_internal_accounts_context, previous_adapter)
        else
          Application.delete_env(:origen, :admin_internal_accounts_context)
        end
      end)

      :ok
    end

    test "lists professional and secretary accounts with role, email, and state without operational controls",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, html} = live(conn, ~p"/administrador/cuentas")

      assert has_element?(view, "#internal-accounts-list")
      assert has_element?(view, "#account-row-101", "dra.garcia@clinicaorigen.com")
      assert has_element?(view, "#account-row-101", "Profesional")
      assert has_element?(view, "#account-row-101", "Activa")

      assert has_element?(view, "#account-row-102", "dr.perez@clinicaorigen.com")
      assert has_element?(view, "#account-row-102", "Pendiente de activación")

      assert has_element?(view, "#account-row-103", "secretaria.ana@clinicaorigen.com")
      assert has_element?(view, "#account-row-103", "Secretaria")
      assert has_element?(view, "#account-row-103", "Activa")

      assert has_element?(view, "#account-row-104", "dr.baja@clinicaorigen.com")
      assert has_element?(view, "#account-row-104", "Desactivada")
      assert has_element?(view, "#account-row-104", "2 turnos futuros afectados")

      # Strictly no operational controls for patients, agendas, payments, or professional settings
      refute html =~ "/secretaria/pacientes"
      refute html =~ "/profesional/agenda"
      refute html =~ "/profesional/ajustes"
    end

    test "reissues invitation for a pending_activation account", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> element("#reissue-invitation-102")
        |> render_click()

      assert html =~ "Invitación reemitida para dr.perez@clinicaorigen.com"
      assert html =~ "reissued_tok_102"
    end

    test "edits account email successfully and preserves account identity", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view
      |> element("#open-edit-account-101")
      |> render_click()

      assert has_element?(view, "#edit-account-form-101")

      html =
        view
        |> form("#edit-account-form-101",
          edit_account: %{email: "dra.garcia.nuevo@clinicaorigen.com"}
        )
        |> render_submit()

      assert html =~ "Correo actualizado a dra.garcia.nuevo@clinicaorigen.com"
      assert has_element?(view, "#account-row-101", "dra.garcia.nuevo@clinicaorigen.com")
      refute has_element?(view, "#edit-account-form-101")
    end

    test "rejects account email edit on duplicate or invalid email with clear feedback", %{
      conn: conn
    } do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view
      |> element("#open-edit-account-101")
      |> render_click()

      # Invalid format
      html =
        view
        |> form("#edit-account-form-101", edit_account: %{email: "correo-invalido"})
        |> render_submit()

      assert html =~ "El formato del correo electrónico no es válido"
      assert has_element?(view, "#account-row-101", "dra.garcia@clinicaorigen.com")

      # Duplicate email (case-insensitive)
      html =
        view
        |> form("#edit-account-form-101",
          edit_account: %{email: "SECRETARIA.ANA@clinicaorigen.com"}
        )
        |> render_submit()

      assert html =~ "Ya existe una cuenta con este correo electrónico"
      assert has_element?(view, "#account-row-101", "dra.garcia@clinicaorigen.com")
    end

    test "deactivates professional account and displays future_affected_appointments_count for Secretary follow-up without automatic cancellation",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> element("#deactivate-account-101")
        |> render_click()

      assert has_element?(view, "#account-row-101", "Desactivada")
      assert html =~ "Cuenta desactivada para dra.garcia@clinicaorigen.com"
      assert html =~ "3 turnos futuros afectados"
      assert html =~ "Secretaría"
      assert html =~ "no se cancelaron automáticamente"
    end

    test "deactivates secretary account and shows 0 future affected appointments", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> element("#deactivate-account-103")
        |> render_click()

      assert has_element?(view, "#account-row-103", "Desactivada")
      assert html =~ "Cuenta desactivada para secretaria.ana@clinicaorigen.com"
    end

    test "reactivates a deactivated account and informs that cancelled appointments are not restored",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> element("#reactivate-account-104")
        |> render_click()

      assert has_element?(view, "#account-row-104", "Activa")
      assert html =~ "Cuenta reactivada para dr.baja@clinicaorigen.com"
      assert html =~ "no restaura turnos cancelados"
    end

    test "canceling account email edit closes the inline form without modifying the account", %{
      conn: conn
    } do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view
      |> element("#open-edit-account-101")
      |> render_click()

      assert has_element?(view, "#edit-account-form-101")

      view
      |> element("#cancel-edit-account-101")
      |> render_click()

      refute has_element?(view, "#edit-account-form-101")
      assert has_element?(view, "#account-row-101", "dra.garcia@clinicaorigen.com")
    end

    test "deactivated pending_activation account returns to pending_activation upon reactivation",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view
      |> element("#deactivate-account-102")
      |> render_click()

      assert has_element?(view, "#account-row-102", "Desactivada")

      view
      |> element("#reactivate-account-102")
      |> render_click()

      assert has_element?(view, "#account-row-102", "Pendiente de activación")
      assert has_element?(view, "#reissue-invitation-102")
    end

    test "denies deactivated administrator session from mounting /administrador/cuentas", %{
      conn: conn
    } do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator, state: "deactivated"})
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/administrador/cuentas")
    end

    test "creating a new staff account adds it to the lifecycle list in pending_activation state",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view
      |> form("#admin-internal-form",
        form: %{role: "professional", email: "nuevo.prof@clinicaorigen.com"}
      )
      |> render_submit()

      assert has_element?(view, "#account-row-105", "nuevo.prof@clinicaorigen.com")
      assert has_element?(view, "#account-row-105", "Profesional")
      assert has_element?(view, "#account-row-105", "Pendiente de activación")
      assert has_element?(view, "#reissue-invitation-105")
      assert has_element?(view, "#deactivate-account-105")
    end

    test "rejected lifecycle operations leave stored accounts state unchanged", %{conn: conn} do
      pid = Application.get_env(:origen, :fake_accounts_agent_pid)
      before_state = Agent.get(pid, & &1)

      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      # Whitespace-only email on edit
      view |> element("#open-edit-account-101") |> render_click()

      html =
        view
        |> form("#edit-account-form-101", edit_account: %{email: "   "})
        |> render_submit()

      assert html =~ "El formato del correo electrónico no es válido"
      assert Agent.get(pid, & &1) == before_state

      # Tampered reissue on active account
      html = render_click(view, "reissue_invitation", %{"id" => "101"})
      assert html =~ "No tiene permiso para realizar esta acción"
      assert Agent.get(pid, & &1) == before_state

      # Tampered deactivate on already deactivated account
      html = render_click(view, "deactivate_account", %{"id" => "104"})
      assert html =~ "Solicitud inválida"
      assert Agent.get(pid, & &1) == before_state

      # Tampered reactivate on already active account
      html = render_click(view, "reactivate_account", %{"id" => "101"})
      assert html =~ "Solicitud inválida"
      assert Agent.get(pid, & &1) == before_state

      # Non-integer ID on lifecycle event
      html = render_click(view, "deactivate_account", %{"id" => "invalid-id"})
      assert html =~ "No tiene permiso para realizar esta acción"
      assert Agent.get(pid, & &1) == before_state
    end

    test "editing email trims surrounding whitespace and preserves id, state, and affected count",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})
      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      view |> element("#open-edit-account-104") |> render_click()

      html =
        view
        |> form("#edit-account-form-104",
          edit_account: %{email: "  dr.baja.actualizado@clinicaorigen.com  "}
        )
        |> render_submit()

      assert html =~ "Correo actualizado a dr.baja.actualizado@clinicaorigen.com"
      assert has_element?(view, "#account-row-104", "dr.baja.actualizado@clinicaorigen.com")
      assert has_element?(view, "#account-affected-turns-104", "2 turnos futuros afectados")
    end
  end

  describe "teclado y foco" do
    # LiveView solo preserva el foco del navegador entre re-renders si el DOM
    # patchea el mismo nodo (mismo id) en vez de reemplazarlo. Verificar la
    # verificación real de foco en el navegador requeriría una herramienta de
    # pruebas end-to-end (Wallaby/Playwright) que este proyecto todavía no
    # tiene configurada; estos tests son la evidencia disponible sin esa
    # infraestructura: los inputs no cambian de id y el valor ya tipeado no
    # se pierde cuando otro campo es inválido.
    test "role and email inputs keep stable DOM ids across a validation re-render", %{
      conn: conn
    } do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, html} = live(conn, ~p"/administrador/cuentas")
      assert html =~ ~s(id="form_role")
      assert html =~ ~s(id="form_email")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "professional", email: "invalid"})
        |> render_change()

      assert html =~ ~s(id="form_role")
      assert html =~ ~s(id="form_email")
    end

    test "keeps the typed email value visible when the role selection is what fails validation",
         %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      html =
        view
        |> form("#admin-internal-form", form: %{role: "", email: "person@example.com"})
        |> render_change()

      assert html =~ "person@example.com"
    end
  end

  describe "accessibility and ARIA feedback" do
    test "result and error banners have proper ARIA live region roles", %{conn: conn} do
      admin = insert_active_account("administrator")
      conn = put_user_in_session(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/administrador/cuentas")

      # Success case has role="status"
      html =
        view
        |> form("#admin-internal-form",
          form: %{role: "professional", email: "aria.success@example.com"}
        )
        |> render_submit()

      assert html =~ ~s(role="status")

      # Duplicate failure has role="alert"
      html =
        view
        |> form("#admin-internal-form",
          form: %{role: "professional", email: "aria.success@example.com"}
        )
        |> render_submit()

      assert html =~ ~s(role="alert")
    end
  end

  describe "styling" do
    test "form container has specified styling", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/administrador/cuentas")

      assert html =~ "bg-white"
      assert html =~ "border-[#E2E8F0]"
      assert html =~ "shadow-[0px_4px_12px_rgba(23,75,99,0.05)]"
      assert html =~ "font-inter"
    end

    test "inputs have specified styling", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/administrador/cuentas")

      assert html =~ "py-[20px]"
      assert html =~ "px-[16px]"
      assert html =~ "rounded-md"
      assert html =~ "focus:ring-2"
      assert html =~ "focus:ring-[#174B63]"
      assert html =~ "focus:border-[#174B63]"
    end

    test "submit button has specified styling", %{conn: conn} do
      conn = put_user_in_session(conn, %{id: 1, role: :administrator})

      {:ok, _view, html} = live(conn, ~p"/administrador/cuentas")

      assert html =~ "phx-disable-with=\"Creando Cuenta...\""
      assert html =~ "bg-[#174B63]"
      assert html =~ "text-white"
      assert html =~ "h-[44px]"
      assert html =~ "px-6"
      assert html =~ "rounded-md"
    end
  end

  defp insert_active_account(role) do
    email = "#{role}_#{System.unique_integer([:positive])}@clinicaorigen.com"

    %{rows: [[id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', 'test_password_hash', 'test_totp_secret', clock_timestamp())
        RETURNING id
        """,
        [email, role]
      )

    %{id: id, role: String.to_atom(role), email: email}
  end

  defp put_user_in_session(conn, user) do
    session_user = Map.new(user, fn {k, v} -> {to_string(k), v} end)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user, session_user)
  end
end

defmodule OrigenWeb.AdminActivationInputSecurityTest do
  use OrigenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Origen.BootstrapAdmin
  alias Origen.Repo
  alias OrigenWeb.AdminActivationSessionStore
  alias OrigenWeb.Layouts

  @verifier_key String.duplicate("v", 32)
  @totp_key String.duplicate("t", 32)

  setup do
    Repo.query!("DELETE FROM internal_account_invitations")
    Repo.query!("DELETE FROM internal_accounts")
    AdminActivationSessionStore.clear()

    previous_verifier_key = Application.get_env(:origen, :bootstrap_admin_verifier_key)
    previous_keyring = Application.get_env(:origen, :bootstrap_admin_totp_keyring)
    previous_ttl = Application.get_env(:origen, :bootstrap_admin_session_ttl_seconds)

    Application.put_env(:origen, :bootstrap_admin_verifier_key, @verifier_key)

    Application.put_env(:origen, :bootstrap_admin_totp_keyring, %{
      active: %{tag: "seed.test.v1", key: @totp_key},
      retired: []
    })

    Application.put_env(:origen, :bootstrap_admin_session_ttl_seconds, 600)

    on_exit(fn ->
      restore_env(:bootstrap_admin_verifier_key, previous_verifier_key)
      restore_env(:bootstrap_admin_totp_keyring, previous_keyring)
      restore_env(:bootstrap_admin_session_ttl_seconds, previous_ttl)
      AdminActivationSessionStore.clear()
    end)

    :ok
  end

  defmodule ActivationFormFixture do
    use Phoenix.Component

    import OrigenWeb.CoreComponents

    def consent_field(assigns) do
      ~H"""
      <.input
        id="activation-consent"
        name="activation_consent"
        type="checkbox"
        label="I accept the activation requirements"
        value={@value}
      />
      """
    end

    def recovery_selector(assigns) do
      ~H"""
      <.input
        id="recovery-method"
        name="recovery_method"
        type="select"
        label="Recovery method"
        prompt="Choose a method"
        options={["Authenticator application": "totp", "Security key": "webauthn"]}
        value={@value}
      />
      """
    end

    def recovery_note(assigns) do
      ~H"""
      <.input
        id="recovery-note"
        name="recovery_note"
        type="textarea"
        label="Recovery note"
        value={@value}
        errors={@errors}
      />
      """
    end

    def primary_action(assigns) do
      ~H"""
      <.button variant="primary">Activate administrator</.button>
      <.button href="/admin/activate">Return to activation</.button>
      """
    end

    def activation_error(assigns) do
      ~H"""
      <.flash id="activation-error" kind={:error} flash={%{}} title="Activation failed">
        Activation details are invalid
      </.flash>
      """
    end
  end

  test "invalid activation submission does not repopulate submitted secrets", %{conn: conn} do
    password = "sentinel-password-must-never-render"
    totp_code = "sentinel-totp-must-never-render"
    invitation = issue_invitation()
    enrollment_conn = exchange(conn, invitation) |> recycle() |> get(https(~p"/admin/activate"))

    body =
      enrollment_conn
      |> recycle()
      |> post(https(~p"/admin/activate"), %{
        "password" => password,
        "password_confirmation" => password,
        "totp_code" => totp_code
      })
      |> html_response(422)

    assert body =~ "Activation details are invalid"
    assert body =~ ~s(name="password")
    assert body =~ ~s(name="password_confirmation")
    assert body =~ ~s(name="totp_code")
    refute body =~ password
    refute body =~ totp_code
    refute body =~ invitation.token
  end

  test "activation consent sends a false fallback and marks explicit consent as checked" do
    unchecked = render_component(&ActivationFormFixture.consent_field/1, %{value: false})
    checked = render_component(&ActivationFormFixture.consent_field/1, %{value: true})

    assert unchecked =~ ~s(type="hidden")
    assert unchecked =~ ~s(name="activation_consent")
    assert unchecked =~ ~s(value="false")
    refute unchecked =~ ~s(checked)
    assert checked =~ ~s(type="checkbox")
    assert checked =~ ~s(checked)
  end

  test "recovery controls expose an explicit selection and preserve text-area validation feedback" do
    selector = render_component(&ActivationFormFixture.recovery_selector/1, %{value: "totp"})

    note =
      render_component(&ActivationFormFixture.recovery_note/1, %{
        value: "Contact security after activation",
        errors: ["must not include a secret"]
      })

    assert selector =~ ~s(<option value="">Choose a method</option>)
    assert selector =~ ~s(<option selected value="totp">Authenticator application</option>)
    assert selector =~ ~s(value="webauthn")
    assert note =~ ~s(<textarea)
    assert note =~ "Contact security after activation"
    assert note =~ "must not include a secret"
  end

  test "activation actions preserve their navigation and submission semantics" do
    html = render_component(&ActivationFormFixture.primary_action/1, %{})

    assert html =~ "<button"
    assert html =~ "Activate administrator"
    assert html =~ ~s(href="/admin/activate")
    assert html =~ "Return to activation"
  end

  test "flash and layout components present activation outcomes to the user" do
    flash = render_component(&ActivationFormFixture.activation_error/1, %{})

    layout = render_component(&Layouts.flash_group/1, %{flash: %{info: "Activation completed"}})

    assert flash =~ ~s(id="activation-error")
    assert flash =~ ~s(role="alert")
    assert flash =~ "Activation failed"
    assert flash =~ "Activation details are invalid"
    assert layout =~ ~s(id="flash-group")
    assert layout =~ "We can&#39;t find the internet"
    assert layout =~ "Attempting to reconnect"
  end

  defp issue_invitation do
    assert {:ok, invitation} = BootstrapAdmin.issue_first(%{verifier_key: @verifier_key})
    invitation
  end

  defp exchange(conn, invitation) do
    conn
    |> post(https(~p"/admin/activate/exchange"), %{
      "invitation_id" => to_string(invitation.invitation_id),
      "token" => invitation.token
    })
  end

  defp https(path), do: "https://www.example.com" <> path

  defp restore_env(key, nil), do: Application.delete_env(:origen, key)
  defp restore_env(key, value), do: Application.put_env(:origen, key, value)
end

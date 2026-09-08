defmodule OrigenWeb.AdminActivationInputSecurityTest do
  use OrigenWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias OrigenWeb.Layouts

  defmodule ActivationFormFixture do
    use Phoenix.Component

    import OrigenWeb.CoreComponents

    def credential_fields(assigns) do
      ~H"""
      <.input
        id="activation-password"
        name="password"
        type="password"
        label="Password"
        value=""
        errors={@errors}
      />
      <.input
        id="activation-confirmation"
        name="password_confirmation"
        type="password"
        label="Confirm password"
        value=""
        errors={@errors}
      />
      <.input
        id="activation-totp"
        name="totp_code"
        type="text"
        label="Authenticator code"
        value=""
        errors={@errors}
      />
      """
    end

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

  test "activation fields render validation feedback without repopulating submitted secrets" do
    html =
      render_component(&ActivationFormFixture.credential_fields/1, %{
        errors: ["Activation details are invalid"]
      })

    assert html =~ ~s(id="activation-password")
    assert html =~ ~s(type="password")
    assert html =~ ~s(name="password_confirmation")
    assert html =~ ~s(name="totp_code")
    assert html =~ "Activation details are invalid"
    refute html =~ "submitted-password"
    refute html =~ "submitted-totp-code"
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
end

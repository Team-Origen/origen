defmodule OrigenWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import Phoenix.LiveViewTest, only: [render_component: 2]

  defmodule ComponentFixture do
    use Phoenix.Component

    import OrigenWeb.CoreComponents
    alias OrigenWeb.Layouts

    def field_input(assigns) do
      ~H"""
      <.input field={@form[:email]} type="email" label="Email" />
      """
    end

    def hidden_input(assigns) do
      ~H"""
      <.input id="return-to" name="return_to" type="hidden" value={@value} />
      """
    end

    def rendered_header(assigns) do
      ~H"""
      <.header>
        Administrator activation
        <:subtitle>Complete the protected enrollment flow</:subtitle>
        <:actions><button type="button">Cancel</button></:actions>
      </.header>
      """
    end

    def administrator_table(assigns) do
      ~H"""
      <.table
        id="administrators"
        rows={@administrators}
        row_id={fn administrator -> "administrator-#{administrator.id}" end}
        row_click={fn administrator -> "select-#{administrator.id}" end}
      >
        <:col :let={administrator} label="Name">{administrator.name}</:col>
        <:col :let={administrator} label="State">{administrator.state}</:col>
        <:action :let={administrator}>
          <a href={"/administrators/#{administrator.id}"}>Inspect {administrator.name}</a>
        </:action>
      </.table>
      """
    end

    def streamed_administrator_table(assigns) do
      ~H"""
      <.table
        id="administrators"
        rows={@administrators}
        row_item={fn {_dom_id, administrator} -> administrator end}
      >
        <:col :let={administrator} label="Name">{administrator.name}</:col>
      </.table>
      """
    end

    def activation_summary(assigns) do
      ~H"""
      <.list>
        <:item title="Account">{@account}</:item>
        <:item title="Invitation">{@invitation}</:item>
      </.list>
      """
    end

    def application_layout(assigns) do
      ~H"""
      <Layouts.app flash={%{}}>
        <p>{@message}</p>
      </Layouts.app>
      """
    end
  end

  test "field-backed and hidden inputs preserve form names, values, and validation errors" do
    changeset =
      {%{}, %{email: :string}}
      |> cast(%{"email" => "invalid"}, [:email])
      |> validate_format(:email, ~r/@/, message: "must contain @")
      |> Map.put(:action, :validate)

    field_html =
      render_component(&ComponentFixture.field_input/1, %{
        form: Phoenix.Component.to_form(changeset, as: :profile)
      })

    hidden_html =
      render_component(&ComponentFixture.hidden_input/1, %{value: "/admin/activate"})

    assert field_html =~ ~s(name="profile[email]")
    assert field_html =~ ~s(value="invalid")
    assert field_html =~ "must contain @"
    assert hidden_html =~ ~s(type="hidden")
    assert hidden_html =~ ~s(name="return_to")
    assert hidden_html =~ ~s(value="/admin/activate")
  end

  test "header presents its title, supporting context, and available action" do
    html = render_component(&ComponentFixture.rendered_header/1, %{})

    assert html =~ "Administrator activation"
    assert html =~ "Complete the protected enrollment flow"
    assert html =~ ~s(type="button")
    assert html =~ "Cancel"
  end

  test "table identifies rows and exposes mapped values, row actions, and click commands" do
    html =
      render_component(&ComponentFixture.administrator_table/1, %{
        administrators: [
          %{id: 7, name: "Santiago", state: "Pending activation"},
          %{id: 9, name: "Ada", state: "Active"}
        ]
      })

    assert html =~ ~s(id="administrator-7")
    assert html =~ ~s(phx-click="select-7")
    assert html =~ "Santiago"
    assert html =~ "Pending activation"
    assert html =~ ~s(href="/administrators/7")
    assert html =~ ~s(id="administrator-9")
    assert html =~ ~s(phx-click="select-9")
    assert html =~ "Ada"
    assert html =~ "Active"
    assert html =~ "Inspect Ada"
  end

  test "table renders a live stream with its default row identifiers" do
    rows =
      Phoenix.LiveView.LiveStream.new(:administrators, 1, [%{id: 7, name: "Santiago"}],
        dom_id: &"administrator-#{&1.id}"
      )

    html =
      render_component(&ComponentFixture.streamed_administrator_table/1, %{
        administrators: rows
      })

    assert html =~ ~s(id="administrator-7")
    assert html =~ ~s(phx-update="stream")
    assert html =~ "Santiago"
  end

  test "list pairs each activation fact with its value" do
    html =
      render_component(&ComponentFixture.activation_summary/1, %{
        account: "account-7",
        invitation: "invitation-11"
      })

    assert html =~ "Account"
    assert html =~ "account-7"
    assert html =~ "Invitation"
    assert html =~ "invitation-11"
  end

  test "validation translation interpolates counts and selects only the requested field" do
    errors = [
      password: {"should be at least %{count} characters", [count: 12]},
      email: {"must contain @", []}
    ]

    assert OrigenWeb.CoreComponents.translate_error(hd(errors) |> elem(1)) ==
             "should be at least 12 characters"

    assert OrigenWeb.CoreComponents.translate_errors(errors, :email) == ["must contain @"]
  end

  test "application layout surrounds page content with primary navigation and feedback regions" do
    html =
      render_component(&ComponentFixture.application_layout/1, %{
        message: "Activation session ready"
      })

    assert html =~ ~s(href="/")
    assert html =~ "Website"
    assert html =~ "GitHub"
    assert html =~ "Get Started"
    assert html =~ "Activation session ready"
    assert html =~ ~s(id="flash-group")
  end
end

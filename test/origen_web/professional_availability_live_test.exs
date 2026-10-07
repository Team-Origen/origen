defmodule OrigenWeb.ProfessionalAvailabilityLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  @path "/configuracion/profesional"

  defmodule UnavailableAvailability do
    def get_own_configuration(_principal), do: {:error, :unavailable}
  end

  defmodule RejectingAvailability do
    def get_own_configuration(principal), do: Origen.Availability.get_own_configuration(principal)
    def replace_own_configuration(_principal, _attributes), do: {:error, :unavailable}
  end

  defmodule TrackingAvailability do
    def get_own_configuration(principal), do: Origen.Availability.get_own_configuration(principal)

    def replace_own_configuration(_principal, _attributes) do
      send(Application.fetch_env!(:origen, :availability_test_pid), :replacement_called)
      {:error, :unexpected_replacement}
    end
  end

  setup %{conn: conn} do
    previous_context = Application.get_env(:origen, :availability_context)

    on_exit(fn ->
      if previous_context do
        Application.put_env(:origen, :availability_context, previous_context)
      else
        Application.delete_env(:origen, :availability_context)
      end
    end)

    professional = insert_active_internal_account!(:professional)

    {:ok, conn: log_in_internal_account(conn, professional), professional_account: professional}
  end

  test "loads the persisted availability summary through the authenticated professional page", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @path)

    assert has_element?(view, "#weekly-availability-heading", "Disponibilidad semanal")
    assert has_element?(view, "#availability-summary", "Lunes")
    assert has_element?(view, "#availability-summary", "08:00 a 12:00")
    assert has_element?(view, "#availability-summary-saturday", "Sábado")
    assert has_element?(view, "#availability-summary-saturday", "Sin disponibilidad")
    assert has_element?(view, "#booking-rules-heading", "Período de reserva")
    assert has_element?(view, "#booking-rules-summary", "30 días")
    assert has_element?(view, "#booking-rules-summary", "30 minutos")
    assert has_element?(view, "#timezone-heading", "Zona horaria")
    assert has_element?(view, "#timezone-summary", "Etc/UTC")
    assert has_element?(view, ~s(button[phx-click="edit_availability"]), "Editar disponibilidad")
    refute has_element?(view, "#availability-form")
  end

  test "rejects anonymous and wrong-role access at the professional route" do
    anonymous_conn = get(build_conn(), @path)
    assert response(anonymous_conn, 401) == "Unauthorized"

    for role <- [:administrator, :secretary] do
      wrong_role_conn =
        build_conn()
        |> log_in_internal_account(insert_active_internal_account!(role))
        |> get(@path)

      assert response(wrong_role_conn, 403) == "Forbidden"
    end
  end

  test "renders the settings navbar first with an honestly disabled agenda action", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    assert has_element?(
             view,
             "#professional-settings-content > #professional-settings-header:first-child",
             "Ajustes"
           )

    assert has_element?(
             view,
             ~s|#back-to-agenda-button[type="button"][disabled][aria-disabled="true"]:not([href]):not([phx-click])|,
             "Volver a Agenda"
           )

    assert has_element?(view, "#back-to-agenda-button .hero-arrow-left")
  end

  test "opens a complete seven-day interval-aware editor with booking controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    view
    |> element(~s(button[phx-click="edit_availability"]), "Editar disponibilidad")
    |> render_click()

    assert has_element?(view, "#availability-form")
    refute has_element?(view, "#availability-summary")

    for day <- ~w(monday tuesday wednesday thursday friday saturday sunday) do
      assert has_element?(view, "#availability-day-#{day}")

      assert has_element?(
               view,
               ~s(button[phx-click="add_availability_window"][phx-value-day="#{day}"])
             )

      assert has_element?(
               view,
               ~s(button[phx-click="clear_availability_day"][phx-value-day="#{day}"])
             )
    end

    assert has_element?(view, ~s(#availability-monday-0-start[type="time"][step="1800"]))
    assert has_element?(view, ~s(#availability-monday-0-end[type="time"][step="1800"]))

    assert has_element?(
             view,
             ~s(#booking-horizon-days[type="number"][min="7"][max="90"][step="1"])
           )

    assert has_element?(
             view,
             ~s(#minimum-lead-minutes[type="number"][min="0"][max="1440"][step="5"])
           )

    assert has_element?(
             view,
             ~s(button[type="button"][phx-click="cancel_availability"]),
             "Cancelar"
           )

    assert has_element?(view, ~s(button[type="submit"]), "Guardar disponibilidad")
  end

  test "presents the configured agenda interval across schedule-window guidance", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    assert has_element?(
             view,
             "#availability-section",
             "Cada horario debe respetar el intervalo de Agenda de 30 minutos."
           )

    assert has_element?(view, ~s(#availability-monday-0-start[step="1800"]))
    assert has_element?(view, ~s(#availability-monday-0-end[step="1800"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[step="5"]))

    invalid =
      put_in(replacement_params(), ["weekly_availability", "monday", "0", "start"], "08:10")

    view
    |> form("#availability-form", availability: invalid)
    |> render_change()

    assert has_element?(
             view,
             "#availability-monday-0-start-error",
             "Debe coincidir con intervalos de 30 minutos."
           )
  end

  test "uses the Origen palette and keeps the atomic editor in one visual section", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    assert has_element?(
             view,
             ~s|main[class~="bg-page"][class~="text-text"][class~="dark:bg-gray-950"][class~="dark:text-gray-100"]|
           )

    open_editor(view)

    assert has_element?(view, "#availability-section > .pc-card.pc-card--basic")

    assert has_element?(
             view,
             ~s|#availability-day-monday[class~="border-border"][class~="bg-surface-muted"][class~="dark:border-gray-700"][class~="dark:bg-gray-800"]|
           )

    assert has_element?(view, "#availability-section #booking-rules-editor")
    assert has_element?(view, "#availability-section .pc-card__footer #availability-form-actions")
    assert has_element?(view, "#availability-form-actions", "Cancelar")
    assert has_element?(view, "#availability-form-actions", "Guardar disponibilidad")
    refute has_element?(view, "#availability-form > #booking-rules-section")

    view
    |> element(~s(button[phx-click="open_new_type"]), "Nuevo tipo de consulta")
    |> render_click()

    assert has_element?(
             view,
             ~s|#new-consultation-type-duration[class~="bg-surface-muted"][class~="text-text-muted"][class~="dark:bg-gray-800"][class~="dark:text-gray-200"]|
           )
  end

  test "blocks an off-interval typed boundary and recovers when the field is corrected", %{
    conn: conn
  } do
    Application.put_env(:origen, :availability_context, TrackingAvailability)
    Application.put_env(:origen, :availability_test_pid, self())
    on_exit(fn -> Application.delete_env(:origen, :availability_test_pid) end)

    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    invalid =
      put_in(replacement_params(), ["weekly_availability", "monday", "0", "start"], "08:10")

    view
    |> form("#availability-form", availability: invalid)
    |> render_change()

    assert has_element?(
             view,
             ~s(#availability-monday-0-start[aria-invalid="true"][aria-describedby="availability-monday-0-start-error"][class*="border-danger-500"])
           )

    assert has_element?(
             view,
             "#availability-monday-0-start-error",
             "Debe coincidir con intervalos de 30 minutos."
           )

    assert has_element?(view, ~s(#availability-save-button[disabled]))

    view
    |> form("#availability-form", availability: invalid)
    |> render_submit()

    refute_received :replacement_called
    assert has_element?(view, "#availability-form")

    valid = put_in(invalid, ["weekly_availability", "monday", "0", "start"], "08:00")

    view
    |> form("#availability-form", availability: valid)
    |> render_change()

    refute has_element?(view, ~s(#availability-monday-0-start[aria-invalid="true"]))
    refute has_element?(view, "#availability-monday-0-start-error")
    assert has_element?(view, "#availability-save-button:not([disabled])")
  end

  test "exposes progressive disclosure and operational narrow-screen day carousel bindings", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @path)

    assert has_element?(
             view,
             ~s(#edit-availability-button[aria-expanded="false"][aria-controls="availability-editor-region"])
           )

    assert has_element?(view, "#availability-editor-region[hidden]")
    assert_day_carousel(view, "summary")
    assert rendered_element_count(view, "#availability-summary-days > *") == 7

    open_editor(view)

    assert has_element?(
             view,
             ~s(#edit-availability-button[aria-expanded="true"][aria-controls="availability-editor-region"])
           )

    assert has_element?(view, "#availability-editor-region:not([hidden])")
    assert_day_carousel(view, "editor")
    assert rendered_element_count(view, "#availability-editor-days > fieldset") == 7
  end

  test "adds, removes, clears, and cancels weekly draft windows without changing persisted state",
       %{
         conn: conn
       } do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    refute has_element?(view, "#availability-saturday-0-start")

    view
    |> element(~s(button[phx-click="add_availability_window"][phx-value-day="saturday"]))
    |> render_click()

    assert has_element?(view, "#availability-saturday-0-start")
    assert has_element?(view, "#availability-saturday-0-end")

    assert has_element?(
             view,
             ~s(button[phx-click="remove_availability_window"][phx-value-day="saturday"][phx-value-index="0"])
           )

    view
    |> element(
      ~s(button[phx-click="remove_availability_window"][phx-value-day="saturday"][phx-value-index="0"])
    )
    |> render_click()

    refute has_element?(view, "#availability-saturday-0-start")
    assert has_element?(view, "#availability-day-saturday", "Sin disponibilidad")

    view
    |> element(~s(button[phx-click="clear_availability_day"][phx-value-day="monday"]))
    |> render_click()

    refute has_element?(view, "#availability-monday-0-start")

    view
    |> element(~s(button[phx-click="cancel_availability"]), "Cancelar")
    |> render_click()

    refute has_element?(view, "#availability-form")
    assert has_element?(view, "#availability-summary-monday", "08:00 a 12:00")

    open_editor(view)
    assert has_element?(view, ~s(#availability-monday-0-start[value="08:00"]))
    assert has_element?(view, ~s(#availability-monday-1-start[value="14:00"]))
  end

  test "saves one complete replacement and adopts backend-normalized touching windows", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    view
    |> form("#availability-form", availability: replacement_params())
    |> render_submit()

    refute has_element?(view, "#availability-form")
    assert has_element?(view, "#availability-save-success[role=status]")
    assert has_element?(view, "#availability-summary-monday", "08:00 a 10:00")
    refute has_element?(view, "#availability-summary-monday", "08:00 a 09:00")
    assert has_element?(view, "#booking-rules-summary", "45 días")
    assert has_element?(view, "#booking-rules-summary", "60 minutos")

    {:ok, remounted_view, _html} = live(conn, @path)
    assert has_element?(remounted_view, "#availability-summary-monday", "08:00 a 10:00")
  end

  test "keeps the rejected draft open and presents one accessible validation notice", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    invalid =
      replacement_params()
      |> put_in(
        ["weekly_availability", "monday"],
        %{
          "_present" => "true",
          "0" => %{"start" => "08:00", "end" => "10:00"},
          "1" => %{"start" => "09:00", "end" => "11:00"}
        }
      )
      |> Map.put("booking_horizon_days", "6")
      |> Map.put("minimum_lead_minutes", "31")

    view
    |> form("#availability-form", availability: invalid)
    |> render_submit()

    assert has_element?(view, "#availability-form")
    assert rendered_element_count(view, "#availability-validation-error[role=alert]") == 1
    assert has_element?(view, "#availability-validation-error", "No se guardaron los cambios")

    assert has_element?(
             view,
             "#availability-validation-error",
             "Lunes: los horarios se superponen."
           )

    assert has_element?(view, "#availability-validation-error", "Período de reserva")
    assert has_element?(view, "#availability-validation-error", "Anticipación mínima")

    assert has_element?(
             view,
             ~s(#availability-monday-1-start[value="09:00"][aria-invalid="true"])
           )

    assert has_element?(view, ~s(#booking-horizon-days[value="6"][aria-invalid="true"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[value="31"][aria-invalid="true"]))

    view
    |> element(~s(button[phx-click="cancel_availability"]), "Cancelar")
    |> render_click()

    assert has_element?(view, "#availability-summary-monday", "08:00 a 12:00")
    assert has_element?(view, "#booking-rules-summary", "30 días")
  end

  test "copies one day's complete draft windows to selected weekdays without persisting a group",
       %{
         conn: conn
       } do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    assert has_element?(view, "#availability-copy-action", "Copiar horarios")
    assert has_element?(view, ~s(#availability-copy-source option[value="monday"]))
    assert has_element?(view, ~s(#availability-copy-saturday[type="checkbox"]))

    view
    |> form("#availability-form",
      copy: %{"source" => "monday", "targets" => ["saturday", "sunday"]}
    )
    |> render_change()

    view

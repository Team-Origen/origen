defmodule OrigenWeb.ProfessionalAvailabilityLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  @path "/configuracion/profesional"

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

  test "opens a complete seven-day interval-aware draft editor", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

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

    view
    |> element(
      ~s(button[phx-click="remove_availability_window"][phx-value-day="saturday"][phx-value-index="0"])
    )
    |> render_click()

    refute has_element?(view, "#availability-saturday-0-start")

    view
    |> element(~s(button[phx-click="clear_availability_day"][phx-value-day="monday"]))
    |> render_click()

    refute has_element?(view, "#availability-monday-0-start")

    view
    |> element(~s(button[phx-click="cancel_availability"]), "Cancelar")
    |> render_click()

    assert has_element?(view, "#availability-summary-monday", "08:00 a 12:00")
  end

  test "edits booking controls inside the weekly availability form", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    assert has_element?(view, ~s(#booking-horizon-days[value="30"][min="7"][max="90"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[value="30"][step="5"]))

    view
    |> element("#availability-form")
    |> render_change(%{
      "availability" => %{"booking_horizon_days" => "45", "minimum_lead_minutes" => "60"}
    })

    assert has_element?(view, ~s(#booking-horizon-days[value="45"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[value="60"]))
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
    assert has_element?(view, "#booking-rules-summary", "45 días")
    assert has_element?(view, "#booking-rules-summary", "60 minutos")
  end

  test "keeps the draft open when saving is temporarily unavailable", %{conn: conn} do
    Application.put_env(:origen, :availability_context, RejectingAvailability)
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    view
    |> form("#availability-form", availability: replacement_params())
    |> render_submit()

    assert has_element?(view, "#availability-form")
    assert has_element?(view, "#availability-save-error[role=alert]", "No se pudo guardar")
  end

  test "exposes operational narrow-screen day carousel bindings", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    assert_day_carousel(view, "summary")
    assert rendered_element_count(view, "#availability-summary-days > *") == 7

    open_editor(view)

    assert_day_carousel(view, "editor")
    assert rendered_element_count(view, "#availability-editor-days > fieldset") == 7
  end

  test "development preview renders the shared component and states that changes are not persisted",
       %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, OrigenWeb.ProfessionalAvailabilityPreviewLive)

    assert has_element?(view, "#availability-development-preview[role=note]", "Vista previa")
    assert has_element?(view, "#availability-development-preview", "no se guardan")
    assert has_element?(view, "#availability-summary-monday", "08:00 a 12:00")

    open_editor(view)

    view
    |> form("#availability-form", availability: replacement_params())
    |> render_submit()

    assert has_element?(view, "#availability-save-success", "Vista previa actualizada")
    assert has_element?(view, "#availability-save-success", "no se guardan")
  end

  test "blocks an off-interval submitted boundary and recovers when corrected", %{conn: conn} do
    Application.put_env(:origen, :availability_context, TrackingAvailability)
    Application.put_env(:origen, :availability_test_pid, self())
    on_exit(fn -> Application.delete_env(:origen, :availability_test_pid) end)

    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    invalid =
      put_in(replacement_params(), ["weekly_availability", "monday", "0", "start"], "08:10")

    view
    |> element("#availability-form")
    |> render_change(%{"availability" => invalid})

    assert has_element?(
             view,
             ~s(#availability-monday-0-start[aria-invalid="true"][aria-describedby="availability-monday-0-start-error"])
           )

    assert has_element?(
             view,
             "#availability-monday-0-start-error",
             "Debe coincidir con intervalos de 30 minutos."
           )

    assert has_element?(view, "#availability-save-button[disabled]")

    view
    |> element("#availability-form")
    |> render_submit(%{"availability" => invalid})

    refute_received :replacement_called

    valid = put_in(invalid, ["weekly_availability", "monday", "0", "start"], "08:00")

    view
    |> element("#availability-form")
    |> render_change(%{"availability" => valid})

    refute has_element?(view, "#availability-monday-0-start-error")
    assert has_element?(view, "#availability-save-button:not([disabled])")
  end

  test "copies one day's complete draft windows to selected weekdays without persisting a group",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    assert has_element?(view, "#availability-copy-action", "Copiar horarios")

    view
    |> form("#availability-form",
      copy: %{"source" => "monday", "targets" => ["saturday", "sunday"]}
    )
    |> render_change()

    view
    |> element(~s(button[phx-click="copy_availability_day"]), "Copiar horarios")
    |> render_click()

    assert has_element?(view, ~s(#availability-saturday-0-start[value="08:00"]))
    assert has_element?(view, ~s(#availability-saturday-1-start[value="14:00"]))
    assert has_element?(view, ~s(#availability-sunday-0-start[value="08:00"]))
    refute has_element?(view, ~s([name="availability[weekday_group]"]))
  end

  defp open_editor(view) do
    view
    |> element(~s(button[phx-click="edit_availability"]), "Editar disponibilidad")
    |> render_click()
  end

  defp replacement_params do
    empty_days =
      Map.new(~w(tuesday wednesday thursday friday saturday sunday), fn day ->
        {day, %{"_present" => "true"}}
      end)

    %{
      "weekly_availability" =>
        Map.put(empty_days, "monday", %{
          "_present" => "true",
          "0" => %{"start" => "08:00", "end" => "09:00"},
          "1" => %{"start" => "09:00", "end" => "10:00"}
        }),
      "booking_horizon_days" => "45",
      "minimum_lead_minutes" => "60"
    }
  end

  defp rendered_element_count(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> LazyHTML.to_tree()
    |> length()
  end

  defp assert_day_carousel(view, name) do
    root = "#availability-#{name}-carousel"
    viewport = "availability-#{name}-days"

    assert has_element?(view, ~s(#{root}[phx-hook$="AvailabilityCarousel"]))

    assert has_element?(
             view,
             ~s(#{root} button[data-carousel-direction="previous"][aria-controls="#{viewport}"])
           )

    assert has_element?(
             view,
             ~s(#{root} button[data-carousel-direction="next"][aria-controls="#{viewport}"])
           )
  end

  defp insert_active_internal_account!(role) do
    %{rows: [[account_id]]} =
      Origen.Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    %{id: account_id, role: role, state: :active}
  end
end

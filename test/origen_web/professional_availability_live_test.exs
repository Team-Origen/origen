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

    assert has_element?(
             view,
             ~s(select#availability-monday-0-start[aria-label="Lunes, horario 1, desde"])
           )

    assert has_element?(
             view,
             ~s(select#availability-monday-0-end[aria-label="Lunes, horario 1, hasta"])
           )

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

    assert has_element?(view, ~s(#availability-monday-0-start option[value="00:30"]))
    assert has_element?(view, ~s(#availability-monday-0-end option[value="24:00"]))
    assert has_element?(view, ~s(#minimum-lead-minutes[step="5"]))

    invalid =
      put_in(replacement_params(), ["weekly_availability", "monday", "0", "start"], "08:10")

    view
    |> element("#availability-form")
    |> render_change(%{"availability" => invalid})

    assert has_element?(
             view,
             "#availability-monday-0-start-error",
             "Seleccione un horario compatible con el intervalo actual de 30 minutos."
           )
  end

  test "uses current-grid selectors and preserves unresolved incompatible draft values", %{
    conn: conn,
    professional_account: professional
  } do
    insert_grid_configuration!(professional.id, 40)
    {:ok, view, _html} = live(conn, @path)
    open_editor(view)

    monday_start = "#availability-monday-0-start"
    monday_end = "#availability-monday-0-end"
    tuesday_start = "#availability-tuesday-0-start"
    monday_error = "availability-monday-0-start-error"

    refute has_element?(view, "#availability-form input[type=time]")

    assert has_element?(
             view,
             ~s(#{monday_start}[aria-label="Lunes, horario 1, desde"][aria-invalid="true"][aria-describedby="#{monday_error}"][class*="border-danger"])
           )

    assert has_element?(view, ~s(#{monday_end}[aria-label="Lunes, horario 1, hasta"]))

    assert has_element?(
             view,
             "##{monday_error}",
             "Seleccione un horario compatible con el intervalo actual de 40 minutos."
           )

    assert has_element?(
             view,
             ~s(#{monday_start} option[value="08:30"][disabled][selected]),
             "08:30 — incompatible con 40 minutos"
           )

    expected_grid = Enum.map(0..1439//40, &format_test_time/1)
    start_options = rendered_option_states(view, "#{monday_start} option")
    end_options = rendered_option_states(view, "#{monday_end} option")

    assert Enum.map(Enum.reject(start_options, & &1.disabled), & &1.value) == expected_grid

    assert Enum.map(Enum.reject(end_options, & &1.disabled), & &1.value) ==
             expected_grid ++ ["24:00"]

    refute Enum.any?(start_options, &(&1.value == "24:00"))
    assert Enum.any?(end_options, &(&1.value == "24:00" and not &1.disabled))
    assert has_element?(view, "#availability-save-button[disabled]")

    view
    |> element("#availability-form")
    |> render_change(%{
      "availability" => grid_availability_params("08:00", nil),
      "copy" => %{"source" => "monday", "targets" => []}
    })

    refute has_element?(view, ~s(#{monday_start}[aria-invalid="true"]))
    assert has_element?(view, ~s(#{tuesday_start}[aria-invalid="true"]))

    assert has_element?(
             view,
             ~s(#{tuesday_start} option[value="08:30"][disabled][selected])
           )

    assert has_element?(view, "#availability-save-button[disabled]")

    view
    |> element("#availability-form")
    |> render_change(%{
      "availability" => grid_availability_params("08:00", "08:00"),
      "copy" => %{"source" => "monday", "targets" => []}
    })

    refute has_element?(view, ~s(#{tuesday_start}[aria-invalid="true"]))
    assert has_element?(view, "#availability-save-button:not([disabled])")
  end

  test "uses the Origen palette and keeps the atomic editor in one visual section", %{conn: conn} do
    {:ok, view, _html} = live(conn, @path)

    assert has_element?(
             view,
             ~s|main[data-theme="light"][class~="bg-page"][class~="text-text"]|
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

  test "blocks an off-interval submitted boundary and recovers when the field is corrected", %{
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
    |> element("#availability-form")
    |> render_change(%{"availability" => invalid})

    assert has_element?(
             view,
             ~s(#availability-monday-0-start[aria-invalid="true"][aria-describedby="availability-monday-0-start-error"][class*="border-danger-500"])
           )

    assert has_element?(
             view,
             "#availability-monday-0-start-error",
             "Seleccione un horario compatible con el intervalo actual de 30 minutos."
           )

    assert has_element?(view, ~s(#availability-save-button[disabled]))

    view
    |> element("#availability-form")
    |> render_submit(%{"availability" => invalid})

    refute_received :replacement_called
    assert has_element?(view, "#availability-form")

    valid = put_in(invalid, ["weekly_availability", "monday", "0", "start"], "08:00")

    view
    |> element("#availability-form")
    |> render_change(%{"availability" => valid})

    refute has_element?(view, ~s(#availability-monday-0-start[aria-invalid="true"]))
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

    assert has_element?(view, ~s(#availability-saturday-0-start option[value="08:00"][selected]))
    assert has_element?(view, ~s(#availability-saturday-1-start option[value="14:00"][selected]))
    assert has_element?(view, ~s(#availability-sunday-0-start option[value="08:00"][selected]))
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

  defp rendered_option_states(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> LazyHTML.to_tree()
    |> Enum.map(fn {"option", attributes, _children} ->
      attributes = Map.new(attributes)

      %{
        value: Map.fetch!(attributes, "value"),
        disabled: Map.has_key?(attributes, "disabled"),
        selected: Map.has_key?(attributes, "selected")
      }
    end)
  end

  defp insert_grid_configuration!(account_id, interval) do
    week =
      Map.new(~w(monday tuesday wednesday thursday friday saturday sunday), &{&1, []})
      |> Map.put("monday", [
        %{"start" => "08:30", "end" => "12:00"},
        %{"start" => "14:00", "end" => "18:00"}
      ])
      |> Map.put("tuesday", [%{"start" => "08:30", "end" => "12:00"}])

    Origen.Repo.query!(
      """
      INSERT INTO agenda_settings (owner_account_id, interval_minutes, weekly_availability)
      VALUES ($1, $2, $3)
      """,
      [account_id, interval, week]
    )
  end

  defp grid_availability_params(monday_start, tuesday_start) do
    window_params = fn start_time ->
      first_window = %{"_present" => "true", "end" => "12:00"}

      if is_nil(start_time),
        do: first_window,
        else: Map.put(first_window, "start", start_time)
    end

    empty_days =
      Map.new(~w(wednesday thursday friday saturday sunday), fn day ->
        {day, %{"_present" => "true"}}
      end)

    %{
      "weekly_availability" =>
        empty_days
        |> Map.put("monday", %{
          "_present" => "true",
          "0" => window_params.(monday_start),
          "1" => %{
            "_present" => "true",
            "start" => "14:00",
            "end" => "18:00"
          }
        })
        |> Map.put("tuesday", %{
          "_present" => "true",
          "0" => window_params.(tuesday_start)
        }),
      "booking_horizon_days" => "30",
      "minimum_lead_minutes" => "30"
    }
  end

  defp format_test_time(minutes) do
    hours = div(minutes, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    remaining = rem(minutes, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hours}:#{remaining}"
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

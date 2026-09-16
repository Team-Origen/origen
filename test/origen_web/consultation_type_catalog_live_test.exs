defmodule OrigenWeb.ConsultationTypeCatalogLiveTest do
  use OrigenWeb.ConnCase

  import Phoenix.LiveViewTest

  @professional_configuration_path "/configuracion/profesional"
  @expected_types [
    %{
      id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
      reference: "TC-001",
      name: "Consulta general",
      count: 2,
      duration: 30,
      price: "ARS 18.000,00",
      color: "#0A7C86",
      status: :active
    },
    %{
      id: "018f4a5b-0d62-7a44-8e32-2f608bfcb002",
      reference: "TC-002",
      name: "Control",
      count: 1,
      duration: 15,
      price: "ARS 12.000,00",
      color: "#4DB5E6",
      status: :active
    },
    %{
      id: "018f4a5b-0d62-7a44-8e32-2f608bfcb003",
      reference: "TC-003",
      name: "Consulta especializada",
      count: 3,
      duration: 45,
      price: "ARS 25.000,00",
      color: "#B47CC7",
      status: :active
    },
    %{
      id: "018f4a5b-0d62-7a44-8e32-2f608bfcb004",
      reference: "TC-004",
      name: "Procedimiento",
      count: 4,
      duration: 60,
      price: "ARS 35.000,00",
      color: "#FFD000",
      status: :active
    },
    %{
      id: "018f4a5b-0d62-7a44-8e32-2f608bfcb005",
      reference: "TC-005",
      name: "Seguimiento",
      count: 2,
      duration: 30,
      price: "ARS 15.000,00",
      color: "#D6F5A3",
      status: :inactive
    },
    %{
      id: "018f4a5b-0d62-7a44-8e32-2f608bfcb006",
      reference: "TC-006",
      name: "Urgencia",
      count: 3,
      duration: 45,
      price: "ARS 30.000,00",
      color: "#FF0000",
      status: :active
    }
  ]

  @active_types Enum.filter(@expected_types, &(&1.status == :active))
  @inactive_type Enum.find(@expected_types, &(&1.status == :inactive))
  @incompatible_inactive_type %{
    id: "018f4a5b-0d62-7a44-8e32-2f608bfcb008",
    name: "Consulta prolongada",
    count: 6,
    duration: 360,
    price: "ARS 30.000,00",
    color: "#8B5CF6"
  }
  @deactivation_warning "Los turnos ya reservados con este tipo de consulta se mantendrán sin cambios. Al desactivarlo, dejará de estar disponible únicamente para nuevas reservas."

  defmodule IncompatibleCatalogAdapter do
    def execute({:list, %{professional_reference: "PRO-DEMO-001"}}) do
      {:ok,
       %{
         source: :demo,
         professional_reference: "PRO-DEMO-001",
         agenda_interval_minutes: 15,
         consultation_types: [
           %{
             id: "018f4a5b-0d62-7a44-8e32-2f608bfcb008",
             reference: "TC-008",
             name: "Consulta prolongada",
             interval_count: 8,
             exact_price_ars: Decimal.new("30000.00"),
             color: "#0A7C86",
             status: :active
           }
         ]
       }}
    end
  end

  defmodule UnavailableCatalogAdapter do
    def execute({:list, %{professional_reference: "PRO-DEMO-001"}}) do
      {:error, :unavailable}
    end
  end

  defmodule ReactivationCatalogAdapter do
    def execute({:list, %{professional_reference: "PRO-DEMO-001"}}) do
      {:ok,
       %{
         source: :demo,
         professional_reference: "PRO-DEMO-001",
         agenda_interval_minutes: 60,
         consultation_types: [
           %{
             id: "018f4a5b-0d62-7a44-8e32-2f608bfcb007",
             reference: "TC-007",
             name: "Consulta inicial",
             interval_count: 2,
             exact_price_ars: Decimal.new("20000.00"),
             color: "#0A7C86",
             status: :active
           },
           %{
             id: "018f4a5b-0d62-7a44-8e32-2f608bfcb008",
             reference: "TC-008",
             name: "Consulta prolongada",
             interval_count: 6,
             exact_price_ars: Decimal.new("30000.00"),
             color: "#8B5CF6",
             status: :inactive,
             inactive_duration_minutes: 360
           },
           %{
             id: "018f4a5b-0d62-7a44-8e32-2f608bfcb009",
             reference: "TC-009",
             name: "Control breve",
             interval_count: 1,
             exact_price_ars: Decimal.new("10000.00"),
             color: "#4DB5E6",
             status: :active
           }
         ]
       }}
    end
  end

  setup do
    previous_adapter = Application.get_env(:origen, :consultation_type_catalog_adapter)

    Application.put_env(
      :origen,
      :consultation_type_catalog_adapter,
      Origen.ConsultationTypes.MockCatalog
    )

    on_exit(fn ->
      if previous_adapter do
        Application.put_env(:origen, :consultation_type_catalog_adapter, previous_adapter)
      else
        Application.delete_env(:origen, :consultation_type_catalog_adapter)
      end
    end)
  end

  test "renders the requested catalog without demo copy or technical references", %{conn: conn} do
    {:ok, view, html} = live(conn, @professional_configuration_path)

    assert has_element?(view, "h1", "Configuración")
    assert has_element?(view, "#agenda-interval-heading", "Intervalo de Agenda")
    assert has_element?(view, "#consultation-types-heading", "Tipos de consulta")
    assert has_element?(view, "#current-agenda-interval", "15 minutos")
    assert has_element?(view, ~s(#agenda-interval-select option[value="5"]), "5 minutos")
    assert has_element?(view, ~s(#agenda-interval-select option[value="240"]), "240 minutos")
    assert html =~ ~s(class="hidden md:block")
    assert html =~ ~s(class="grid gap-4 md:hidden")

    refute has_element?(view, "main", "Datos de demostración")
    refute has_element?(view, "main", "información simulada")
    refute has_element?(view, "main", "vista no productiva")
    refute has_element?(view, "th", "Referencia")
    refute has_element?(view, "dt", "Referencia")
    refute has_element?(view, "th", "Color")
    refute has_element?(view, "dt", "Color")
    refute has_element?(view, "main", "PRO-DEMO-001")

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    for type <- @expected_types do
      row = "#consultation-type-#{type.id}"
      card = "#consultation-type-mobile-#{type.id}"
      swatch_label = "Color asignado a #{type.name}"

      assert has_element?(view, row, type.name)
      assert has_element?(view, row, "Cantidad de intervalos #{type.count}")
      assert has_element?(view, row, "Duración: #{type.duration} minutos")
      assert has_element?(view, row, type.price)

      assert has_element?(
               view,
               ~s(#{row} [role="img"][aria-label="#{swatch_label}"][title="#{swatch_label}"][style="background-color: #{type.color}"])
             )

      assert has_element?(view, card, type.name)
      assert has_element?(view, card, "Cantidad de intervalos #{type.count}")
      assert has_element?(view, card, "Duración: #{type.duration} minutos")
      assert has_element?(view, card, type.price)
      refute has_element?(view, "main", type.reference)
      refute has_element?(view, "main", type.id)
      refute has_element?(view, "main", type.color)
    end
  end

  test "filters inactive consultation types without losing the catalog snapshot", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)

    inactive_row = "#consultation-type-#{@inactive_type.id}"
    inactive_card = "#consultation-type-mobile-#{@inactive_type.id}"

    assert has_element?(view, "#consultation-types-filter label", "Mostrar consultas inactivas")

    assert has_element?(
             view,
             ~s|#show-inactive-consultation-types[type="checkbox"][name="show_inactive"]:not([checked])|
           )

    refute has_element?(view, inactive_row)
    refute has_element?(view, inactive_card)

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    assert has_element?(view, "#show-inactive-consultation-types[checked]")
    assert has_element?(view, inactive_row, @inactive_type.name)
    assert has_element?(view, inactive_card, @inactive_type.name)

    view
    |> form("#consultation-types-filter", show_inactive: "false")
    |> render_change()

    assert has_element?(view, "#show-inactive-consultation-types:not([checked])")
    refute has_element?(view, inactive_row)
    refute has_element?(view, inactive_card)
  end

  test "a pending interval selection warns without applying immediately", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)

    view
    |> form("#agenda-interval-form", interval_minutes: "30")
    |> render_change()

    assert has_element?(view, "#current-agenda-interval", "15 minutos")
    assert has_element?(view, "#interval-change-warning[role=alert]")

    assert has_element?(
             view,
             "#interval-change-warning",
             "Las cantidades de intervalos no cambiarán"
           )

    assert has_element?(view, "#interval-change-warning", "Consulta general")
    assert has_element?(view, "#interval-change-warning", "30 a 60 minutos")
    refute has_element?(view, "#interval-change-warning", "TC-001")

    assert has_element?(
             view,
             "#consultation-type-018f4a5b-0d62-7a44-8e32-2f608bfcb001",
             "Duración: 30 minutos"
           )
  end

  test "a compatible apply recalculates durations and preserves counts", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)

    view
    |> form("#agenda-interval-form", interval_minutes: "30")
    |> render_submit()

    row = "#consultation-type-018f4a5b-0d62-7a44-8e32-2f608bfcb001"

    assert has_element?(view, "#current-agenda-interval", "30 minutos")
    assert has_element?(view, "#interval-apply-success[role=status]")
    assert has_element?(view, row, "Cantidad de intervalos 2")
    assert has_element?(view, row, "Duración: 60 minutos")
    refute has_element?(view, "#interval-change-warning")
  end

  test "an inactive type preserves its deactivation duration until compatible reactivation", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    active_type = Enum.at(@active_types, 1)
    row = "#consultation-type-#{type.id}"

    show_inactive(view)

    view
    |> element("##{deactivation_dialog_id(type)} [data-pc-alert-dialog-confirm]")
    |> render_click()

    assert has_element?(view, row, "Duración: 30 minutos")
    assert has_element?(view, row, "Inactivo")

    view
    |> form("#agenda-interval-form", interval_minutes: "30")
    |> render_change()

    assert has_element?(view, "#interval-change-warning", "Control")
    assert has_element?(view, "#interval-change-warning", "15 a 30 minutos")

    view
    |> form("#agenda-interval-form", interval_minutes: "30")
    |> render_submit()

    assert has_element?(view, "#current-agenda-interval", "30 minutos")
    assert has_element?(view, row, "Duración: 30 minutos")

    assert has_element?(
             view,
             "#consultation-type-#{active_type.id}",
             "Duración: 30 minutos"
           )

    view
    |> element(~s(#{row} button[phx-click="reactivate_type"]), "Reactivar")
    |> render_click()

    assert has_element?(view, row, "Duración: 60 minutos")
    assert has_element?(view, row, "Activo")
  end

  test "an incompatible apply is rejected without inferring a replacement count", %{conn: conn} do
    Application.put_env(
      :origen,
      :consultation_type_catalog_adapter,
      IncompatibleCatalogAdapter
    )

    {:ok, view, _html} = live(conn, @professional_configuration_path)

    view
    |> form("#agenda-interval-form", interval_minutes: "60")
    |> render_submit()

    row = "#consultation-type-018f4a5b-0d62-7a44-8e32-2f608bfcb008"

    assert has_element?(view, "#interval-apply-error[role=alert]", "No se aplicó el intervalo")
    assert has_element?(view, "#interval-apply-error", "máximo de 4")
    assert has_element?(view, "#interval-apply-error", "Consulta prolongada")
    refute has_element?(view, "#interval-apply-error", "TC-008")
    assert has_element?(view, "#current-agenda-interval", "15 minutos")
    assert has_element?(view, row, "Cantidad de intervalos 8")
    assert has_element?(view, row, "Duración: 120 minutos")
  end

  test "actions follow consultation status and target stable IDs", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)

    assert has_element?(
             view,
             ~s|button:not([disabled])[phx-click="open_new_type"]|,
             "Nuevo tipo de consulta"
           )

    for type <- @active_types,
        container <- ["#consultation-type-#{type.id}", "#consultation-type-mobile-#{type.id}"] do
      assert has_element?(
               view,
               ~s|#{container} button:not([disabled])[phx-click="open_edit_type"][phx-value-id="#{type.id}"]|,
               "Editar"
             )

      assert has_element?(view, "#{container} button:not([disabled])", "Desactivar")
      refute has_element?(view, "#{container} button", "Reactivar")
    end

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    for container <- [
          "#consultation-type-#{@inactive_type.id}",
          "#consultation-type-mobile-#{@inactive_type.id}"
        ] do
      assert has_element?(
               view,
               ~s|#{container} button:not([disabled])[phx-click="reactivate_type"][phx-value-id="#{@inactive_type.id}"]|,
               "Reactivar"
             )

      refute has_element?(view, "#{container} button", "Editar")
      refute has_element?(view, "#{container} button", "Desactivar")
    end

    refute has_element?(view, "button[disabled][phx-click]")
  end

  test "a compatible inactive type reactivates unchanged in place and exposes active actions", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    show_inactive(view)

    row = "#consultation-type-#{@inactive_type.id}"
    card = "#consultation-type-mobile-#{@inactive_type.id}"
    initial_item_count = rendered_catalog_item_count(view)

    assert has_element?(view, "#consultation-types-table-view tbody tr:nth-child(5)#{row}")

    view
    |> element(~s(#{row} button[phx-click="reactivate_type"]), "Reactivar")
    |> render_click()

    assert rendered_catalog_item_count(view) == initial_item_count
    assert has_element?(view, "#consultation-types-table-view tbody tr:nth-child(5)#{row}")

    for container <- [row, card] do
      assert has_element?(view, container, @inactive_type.name)
      assert has_element?(view, container, "Cantidad de intervalos #{@inactive_type.count}")
      assert has_element?(view, container, "Duración: #{@inactive_type.duration} minutos")
      assert has_element?(view, container, @inactive_type.price)
      assert has_element?(view, container, "Activo")
      assert has_element?(view, "#{container} button", "Editar")
      assert has_element?(view, "#{container} button", "Desactivar")
      refute has_element?(view, "#{container} button", "Reactivar")
    end

    view
    |> form("#consultation-types-filter", show_inactive: "false")
    |> render_change()

    assert has_element?(view, row, @inactive_type.name)
  end

  test "an incompatible reactivation opens the focused modal without changing the type", %{
    conn: conn
  } do
    use_reactivation_catalog()
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    open_incompatible_reactivation(view)

    row = "#consultation-type-#{@incompatible_inactive_type.id}"

    assert has_element?(
             view,
             ~s(#reactivate-consultation-type-modal [role="dialog"]),
             "Reactivar tipo de consulta"
           )

    assert has_element?(
             view,
             "#reactivate-consultation-type-modal",
             "La cantidad actual no es válida para el Intervalo de Agenda aplicado"
           )

    assert has_element?(view, "#reactivation-current-count", "6")
    assert has_element?(view, "#reactivation-current-duration", "360 minutos")
    assert has_element?(view, "#reactivation-effective-maximum", "4 intervalos")
    assert has_element?(view, row, "Cantidad de intervalos 6")
    assert has_element?(view, row, "Inactivo")

    assert has_element?(
             view,
             ~s(#reactivation-interval-count[role="spinbutton"][value=""][aria-valuemin="1"][aria-valuemax="4"])
           )

    assert has_element?(
             view,
             ~s(#reactivation-interval-count-field[data-min="1"][data-max="4"][data-step="1"])
           )

    assert rendered_element_count(
             view,
             "#reactivation-interval-count-field [data-pc-number-step]"
           ) == 2

    assert has_element?(view, "output#reactivation-duration", "—")
    assert has_element?(view, "#reactivate-consultation-type-modal button", "Reactivar")
    assert has_element?(view, "#reactivate-consultation-type-modal button", "Cancelar")
  end

  test "replacement duration updates and explicit confirmation applies count and status atomically",
       %{
         conn: conn
       } do
    use_reactivation_catalog()
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    open_incompatible_reactivation(view)

    row = "#consultation-type-#{@incompatible_inactive_type.id}"
    card = "#consultation-type-mobile-#{@incompatible_inactive_type.id}"
    initial_item_count = rendered_catalog_item_count(view)

    view
    |> form("#reactivate-consultation-type-form", reactivation: %{interval_count: "3"})
    |> render_change()

    assert has_element?(view, "output#reactivation-duration", "180 minutos")

    view
    |> form("#reactivate-consultation-type-form", reactivation: %{interval_count: "3"})
    |> render_submit()

    refute has_element?(view, "#reactivate-consultation-type-modal")
    assert rendered_catalog_item_count(view) == initial_item_count
    assert has_element?(view, "#consultation-types-table-view tbody tr:nth-child(2)#{row}")

    for container <- [row, card] do
      assert has_element?(view, container, @incompatible_inactive_type.name)
      assert has_element?(view, container, "Cantidad de intervalos 3")
      assert has_element?(view, container, "Duración: 180 minutos")
      assert has_element?(view, container, @incompatible_inactive_type.price)
      assert has_element?(view, container, "Activo")

      assert has_element?(
               view,
               ~s(#{container} [role="img"][style="background-color: #{@incompatible_inactive_type.color}"])
             )

      assert has_element?(view, "#{container} button", "Editar")
      assert has_element?(view, "#{container} button", "Desactivar")
      refute has_element?(view, "#{container} button", "Reactivar")
    end
  end

  test "blank malformed and out-of-range replacements keep the original inactive type", %{
    conn: conn
  } do
    for invalid_count <- ["", "cantidad", "0", "5"] do
      use_reactivation_catalog()
      {:ok, view, _html} = live(conn, @professional_configuration_path)
      open_incompatible_reactivation(view)

      render_submit(view, "confirm_reactivation", %{
        "reactivation" => %{"interval_count" => invalid_count}
      })

      row = "#consultation-type-#{@incompatible_inactive_type.id}"

      assert has_element?(view, "#reactivate-consultation-type-modal")

      assert has_element?(
               view,
               "#reactivation-errors[role=alert]",
               "continúa inactivo y no se realizaron cambios"
             )

      assert has_element?(view, ".pc-form-field-error", "La cantidad debe estar entre 1 y 4")

      assert has_element?(
               view,
               ~s(#reactivation-interval-count[aria-invalid="true"][aria-describedby="reactivation-errors"])
             )

      assert has_element?(view, row, "Cantidad de intervalos 6")
      assert has_element?(view, row, "Duración: 360 minutos")
      assert has_element?(view, row, "Inactivo")
      refute has_element?(view, row, "Cantidad de intervalos 4")
    end
  end

  test "reactivation cancellation paths preserve the type and reset replacement state", %{
    conn: conn
  } do
    use_reactivation_catalog()
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    row = "#consultation-type-#{@incompatible_inactive_type.id}"

    open_incompatible_reactivation(view)

    view
    |> form("#reactivate-consultation-type-form", reactivation: %{interval_count: "3"})
    |> render_change()

    view
    |> element("#reactivate-consultation-type-modal button", "Cancelar")
    |> render_click()

    refute has_element?(view, "#reactivate-consultation-type-modal")
    assert has_element?(view, row, "Cantidad de intervalos 6")
    assert has_element?(view, row, "Inactivo")

    open_incompatible_reactivation(view)
    assert has_element?(view, ~s(#reactivation-interval-count[value=""]))

    assert has_element?(
             view,
             ~s(#reactivate-consultation-type-modal[data-cancel*="cancel_reactivation"])
           )

    assert has_element?(view, "#reactivate-consultation-type-modal .pc-modal__header__button")
    render_click(view, "cancel_reactivation")

    refute has_element?(view, "#reactivate-consultation-type-modal")
    assert has_element?(view, row, "Cantidad de intervalos 6")
    assert has_element?(view, row, "Inactivo")

    open_incompatible_reactivation(view)
    assert has_element?(view, ~s(#reactivation-interval-count[value=""]))
  end

  test "forged reactivation and replacement events fail closed", %{conn: conn} do
    {:ok, default_view, _html} = live(conn, @professional_configuration_path)
    show_inactive(default_view)
    default_html = render(default_view)

    render_click(default_view, "reactivate_type", %{"id" => Ecto.UUID.generate()})
    assert render(default_view) == default_html

    render_click(default_view, "reactivate_type", %{"id" => hd(@active_types).id})
    assert render(default_view) == default_html

    render_click(default_view, "reactivate_type", %{})
    assert render(default_view) == default_html

    use_reactivation_catalog()
    {:ok, incompatible_view, _html} = live(conn, @professional_configuration_path)
    show_inactive(incompatible_view)
    incompatible_html = render(incompatible_view)

    render_submit(incompatible_view, "confirm_reactivation", %{
      "reactivation" => %{"interval_count" => "4"}
    })

    assert render(incompatible_view) == incompatible_html

    render_click(incompatible_view, "change_reactivation", %{
      "reactivation" => %{"interval_count" => "4"}
    })

    assert render(incompatible_view) == incompatible_html

    render_click(incompatible_view, "reactivate_type", %{
      "id" => @incompatible_inactive_type.id
    })

    assert has_element?(incompatible_view, "#reactivate-consultation-type-modal")

    assert has_element?(
             incompatible_view,
             "#consultation-type-#{@incompatible_inactive_type.id}",
             "Cantidad de intervalos 6"
           )

    assert has_element?(
             incompatible_view,
             "#consultation-type-#{@incompatible_inactive_type.id}",
             "Inactivo"
           )
  end

  test "active deactivation triggers share one accessible Petal confirmation per stable ID", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    dialog_id = deactivation_dialog_id(type)

    for presentation <- ~w(desktop mobile) do
      trigger = deactivation_trigger_selector(type, presentation)

      assert has_element?(
               view,
               ~s(#{trigger}[aria-controls="#{dialog_id}"][phx-click*="pc:alert-dialog-open"]),
               "Desactivar"
             )
    end

    assert rendered_element_count(view, "##{dialog_id}") == 1

    assert rendered_element_count(view, ~s(dialog[id^="deactivate-consultation-type-"])) ==
             length(@active_types)

    assert has_element?(
             view,
             ~s|##{dialog_id}[role="alertdialog"][aria-modal="true"][aria-labelledby="#{dialog_id}-title"][aria-describedby="#{dialog_id}-description"]:not(.pc-alert-dialog--destructive)|
           )

    assert has_element?(view, "##{dialog_id}-title", "Desactivar tipo de consulta")
    assert has_element?(view, "##{dialog_id}-description", @deactivation_warning)

    assert has_element?(
             view,
             ~s(##{dialog_id} [data-pc-alert-dialog-cancel][phx-click*="cancel_deactivate_type"]),
             "Cancelar"
           )

    assert has_element?(
             view,
             ~s(##{dialog_id} [data-pc-alert-dialog-confirm][phx-click*="deactivate_type"][phx-click*="#{type.id}"]),
             "Desactivar"
           )
  end

  test "opening, canceling, and the Escape-equivalent cancel event do not mutate the catalog", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    target_row = "#consultation-type-#{type.id}"
    initial_html = render(view)

    trigger = deactivation_trigger_selector(type, "desktop")

    assert has_element?(view, ~s(#{trigger}[phx-click*="pc:alert-dialog-open"]))
    refute has_element?(view, ~s(#{trigger}[phx-click*="push"]))

    assert render(view) == initial_html
    assert has_element?(view, target_row, "Activo")

    view
    |> element("##{deactivation_dialog_id(type)} [data-pc-alert-dialog-cancel]")
    |> render_click()

    assert render(view) == initial_html

    render_click(view, "cancel_deactivate_type", %{"id" => type.id})

    assert render(view) == initial_html
    assert has_element?(view, target_row, type.name)
    assert has_element?(view, target_row, "Activo")
  end

  test "explicit confirmation deactivates exactly one stable-ID target in place", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    untouched_type = Enum.at(@active_types, 1)
    target_row = "#consultation-type-#{type.id}"
    target_card = "#consultation-type-mobile-#{type.id}"
    initial_item_count = rendered_catalog_item_count(view)

    view
    |> element("##{deactivation_dialog_id(type)} [data-pc-alert-dialog-confirm]")
    |> render_click()

    assert rendered_catalog_item_count(view) == initial_item_count - 2
    refute has_element?(view, target_row)
    refute has_element?(view, target_card)
    assert has_element?(view, "#consultation-type-#{untouched_type.id}", "Activo")

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    assert has_element?(view, "#consultation-types-table-view tbody tr:first-child#{target_row}")
    assert has_element?(view, target_row, type.name)
    assert has_element?(view, target_row, "Cantidad de intervalos #{type.count}")
    assert has_element?(view, target_row, "Duración: #{type.duration} minutos")
    assert has_element?(view, target_row, type.price)
    assert has_element?(view, target_row, "Inactivo")

    assert has_element?(
             view,
             ~s(#{target_row} [role="img"][style="background-color: #{type.color}"])
           )

    assert has_element?(view, "#consultation-type-#{untouched_type.id}", "Activo")
  end

  test "confirmation keeps the item visible as inactive when the filter is checked", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = Enum.at(@active_types, 2)

    target_containers = [
      "#consultation-type-#{type.id}",
      "#consultation-type-mobile-#{type.id}"
    ]

    initial_item_count = rendered_catalog_item_count(view)

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    view
    |> element("##{deactivation_dialog_id(type)} [data-pc-alert-dialog-confirm]")
    |> render_click()

    assert rendered_catalog_item_count(view) == initial_item_count + 2

    for container <- target_containers do
      assert has_element?(view, container, type.name)
      assert has_element?(view, container, "Inactivo")
      assert has_element?(view, "#{container} button:not([disabled])", "Reactivar")
      refute has_element?(view, "#{container} button", "Editar")
      refute has_element?(view, "#{container} button", "Desactivar")
    end
  end

  test "missing, inactive, and repeated deactivation confirmations fail closed", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    initial_html = render(view)

    render_click(view, "deactivate_type", %{"id" => Ecto.UUID.generate()})
    assert render(view) == initial_html

    render_click(view, "deactivate_type", %{"id" => @inactive_type.id})
    assert render(view) == initial_html

    render_click(view, "deactivate_type", %{})
    assert render(view) == initial_html

    render_click(view, "deactivate_type", %{"id" => type.id})
    item_count_after_confirmation = rendered_catalog_item_count(view)

    render_click(view, "deactivate_type", %{"id" => type.id})

    assert rendered_catalog_item_count(view) == item_count_after_confirmation
    assert has_element?(view, "#consultation-type-#{type.id}", "Inactivo")
    assert has_element?(view, "#consultation-type-#{@inactive_type.id}", "Inactivo")
  end

  test "active edit opens the shared form with accepted current values and live duration", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)

    open_edit_type_modal(view, type)

    assert has_element?(
             view,
             ~s(#new-consultation-type-modal [role="dialog"]),
             "Editar tipo de consulta"
           )

    assert has_element?(view, "#new-consultation-type-modal button", "Guardar cambios")
    refute has_element?(view, "#new-consultation-type-modal button", "Agregar tipo de consulta")
    assert has_element?(view, ~s(#new-consultation-type-name[value="Consulta general"]))
    assert has_element?(view, ~s(#new-consultation-type-price[value="18.000,00"]))
    assert has_element?(view, ~s(#new-consultation-type-color[value="#0A7C86"]))
    assert has_element?(view, ~s(#new-consultation-type-count[value="2"]))

    assert has_element?(
             view,
             ~s(#new-consultation-type-currency option[value="ARS"][selected]),
             "ARS"
           )

    assert has_element?(view, "output#new-consultation-type-duration", "30 minutos")

    view
    |> form("#new-consultation-type-form",
      consultation_type: edit_type_params(type, interval_count: "3")
    )
    |> render_change()

    assert has_element?(view, "output#new-consultation-type-duration", "45 minutos")
  end

  test "valid edit updates only its target in place and derives duration", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    initial_item_count = rendered_catalog_item_count(view)
    target_row = "#consultation-type-#{type.id}"
    untouched_row = "#consultation-type-#{Enum.at(@active_types, 1).id}"

    assert has_element?(view, "#consultation-types-table-view tbody tr:first-child#{target_row}")
    open_edit_type_modal(view, type)

    render_submit(view, "save_type", %{
      "consultation_type" =>
        edit_type_params(type,
          name: "Consulta prioritaria",
          exact_price_ars: "19.500,50",
          color: "#123abc",
          interval_count: "3"
        )
        |> Map.put("duration", "1")
    })

    refute has_element?(view, "#new-consultation-type-modal")
    assert rendered_catalog_item_count(view) == initial_item_count
    assert has_element?(view, "#consultation-types-table-view tbody tr:first-child#{target_row}")
    assert has_element?(view, target_row, "Consulta prioritaria")
    assert has_element?(view, target_row, "Cantidad de intervalos 3")
    assert has_element?(view, target_row, "Duración: 45 minutos")
    assert has_element?(view, target_row, "ARS 19.500,50")
    assert has_element?(view, target_row, "Activo")
    refute has_element?(view, target_row, "Consulta general")
    refute has_element?(view, target_row, "Duración: 1 minutos")
    assert has_element?(view, untouched_row, "Control")
    assert has_element?(view, untouched_row, "ARS 12.000,00")
  end

  test "duplicate names remain valid when editing", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    initial_item_count = rendered_catalog_item_count(view)
    existing_control_row = "#consultation-type-#{Enum.at(@active_types, 1).id}"
    edited_row = "#consultation-type-#{type.id}"

    open_edit_type_modal(view, type)

    view
    |> form("#new-consultation-type-form",
      consultation_type: edit_type_params(type, name: "Control")
    )
    |> render_submit()

    assert rendered_catalog_item_count(view) == initial_item_count
    assert has_element?(view, edited_row, "Control")
    assert has_element?(view, existing_control_row, "Control")
  end

  test "invalid edit stays open with accessible errors and preserves the original", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    initial_item_count = rendered_catalog_item_count(view)
    target_row = "#consultation-type-#{type.id}"

    open_edit_type_modal(view, type)

    render_submit(view, "save_type", %{
      "consultation_type" =>
        edit_type_params(type, name: "   ", currency: "USD", interval_count: "0")
    })

    assert has_element?(view, "#new-consultation-type-modal", "Editar tipo de consulta")
    assert has_element?(view, "#new-consultation-type-errors[role=alert]", "No se guardaron")
    assert has_element?(view, ".pc-form-field-error", "Ingrese un nombre")
    assert has_element?(view, ".pc-form-field-error", "Seleccione una moneda válida")
    assert has_element?(view, ".pc-form-field-error", "La cantidad debe estar entre 1 y 10")
    assert has_element?(view, ~s(#new-consultation-type-name[aria-invalid="true"]))
    assert has_element?(view, ~s(#new-consultation-type-currency[aria-invalid="true"]))
    assert has_element?(view, ~s(#new-consultation-type-count[aria-invalid="true"]))
    assert rendered_catalog_item_count(view) == initial_item_count
    assert has_element?(view, target_row, "Consulta general")
    assert has_element?(view, target_row, "Cantidad de intervalos 2")
    assert has_element?(view, target_row, "ARS 18.000,00")
  end

  test "all modal cancellation paths preserve the edit target and reset create mode", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    type = hd(@active_types)
    target_row = "#consultation-type-#{type.id}"
    initial_item_count = rendered_catalog_item_count(view)

    for cancel <- [:button, :close, :cancel_event] do
      open_edit_type_modal(view, type)

      view
      |> form("#new-consultation-type-form",
        consultation_type: edit_type_params(type, name: "Cambio descartado")
      )
      |> render_change()

      case cancel do
        :button ->
          view
          |> element("#new-consultation-type-modal button", "Cancelar")
          |> render_click()

        :close ->
          assert has_element?(view, "#new-consultation-type-modal .pc-modal__header__button")

          assert has_element?(
                   view,
                   ~s(#new-consultation-type-modal[data-cancel*="cancel_type"])
                 )

          render_click(view, "cancel_type")

        :cancel_event ->
          render_click(view, "cancel_type")
      end

      refute has_element?(view, "#new-consultation-type-modal")
      assert rendered_catalog_item_count(view) == initial_item_count
      assert has_element?(view, target_row, "Consulta general")
      refute has_element?(view, target_row, "Cambio descartado")
    end

    open_new_type_modal(view)

    assert has_element?(view, "#new-consultation-type-modal", "Nuevo tipo de consulta")
    assert has_element?(view, "#new-consultation-type-modal button", "Agregar tipo de consulta")
    refute has_element?(view, "#new-consultation-type-modal button", "Guardar cambios")
    assert has_element?(view, ~s(#new-consultation-type-name[value=""]))
    assert has_element?(view, ~s(#new-consultation-type-price[value=""]))
    assert has_element?(view, ~s(#new-consultation-type-count[value="1"]))
  end

  test "inactive and missing forged edit targets fail closed", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)

    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()

    inactive_row = "#consultation-type-#{@inactive_type.id}"
    assert has_element?(view, inactive_row, @inactive_type.name)
    refute has_element?(view, "#{inactive_row} button", "Editar")

    render_click(view, "open_edit_type", %{"id" => @inactive_type.id})
    refute has_element?(view, "#new-consultation-type-modal")

    render_click(view, "open_edit_type", %{"id" => Ecto.UUID.generate()})
    refute has_element?(view, "#new-consultation-type-modal")
    assert rendered_catalog_item_count(view) == initial_item_count + 2
    assert has_element?(view, inactive_row, @inactive_type.name)
    assert has_element?(view, inactive_row, "Inactivo")
  end

  test "opens the creation modal and cancel resets it without changing the catalog", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)

    open_new_type_modal(view)

    assert has_element?(
             view,
             ~s(#new-consultation-type-modal [role="dialog"]),
             "Nuevo tipo de consulta"
           )

    assert has_element?(view, "#new-consultation-type-name")

    assert has_element?(
             view,
             ~s(#new-consultation-type-currency[name="consultation_type[currency]"][aria-label="Moneda del precio"] option[value="ARS"]),
             "ARS"
           )

    assert render(view)
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("#new-consultation-type-currency option")
           |> LazyHTML.to_tree()
           |> length() == 1

    assert has_element?(
             view,
             ~s|#new-consultation-type-price[type="text"][inputmode="decimal"]:not([min]):not([max]):not([step])|
           )

    assert has_element?(view, "#new-consultation-type-color")

    assert has_element?(
             view,
             ~s(#new-consultation-type-count[type="number"][min="1"][max="10"][step="1"])
           )

    assert render(view)
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("#new-consultation-type-modal input[type=number]")
           |> LazyHTML.to_tree()
           |> length() == 1

    refute has_element?(view, "#new-consultation-type-form", "Referencia")
    refute has_element?(view, "#new-consultation-type-form", "Estado")

    view
    |> form("#new-consultation-type-form", consultation_type: valid_new_type(name: "Temporal"))
    |> render_change()

    view
    |> element("#new-consultation-type-modal button", "Cancelar")
    |> render_click()

    refute has_element?(view, "#new-consultation-type-modal")
    assert rendered_catalog_item_count(view) == initial_item_count

    open_new_type_modal(view)

    assert has_element?(view, ~s(#new-consultation-type-name[value=""]))
    refute has_element?(view, "#new-consultation-type-form", "Temporal")

    view
    |> form("#new-consultation-type-form",
      consultation_type: valid_new_type(name: "Otro temporal")
    )
    |> render_change()

    assert has_element?(view, "#new-consultation-type-modal .pc-modal__header__button")
    render_click(view, "cancel_type")

    refute has_element?(view, "#new-consultation-type-modal")
    assert rendered_catalog_item_count(view) == initial_item_count

    open_new_type_modal(view)
    assert has_element?(view, ~s(#new-consultation-type-name[value=""]))
  end

  test "a valid submission adds exactly one active type to both responsive views", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)
    open_new_type_modal(view)

    view
    |> form("#new-consultation-type-form",
      consultation_type:
        valid_new_type(
          name: "Evaluación inicial",
          exact_price_ars: "18.000,00",
          color: "#123abc",
          interval_count: "2"
        )
    )
    |> render_submit()

    refute has_element?(view, "#new-consultation-type-modal")
    assert rendered_catalog_item_count(view) == initial_item_count + 2

    table_row = "#consultation-types-table-view tbody tr:last-child"
    mobile_card = "#consultation-types-mobile-view article:last-child"

    for container <- [table_row, mobile_card] do
      assert has_element?(view, container, "Evaluación inicial")
      assert has_element?(view, container, "Cantidad de intervalos 2")
      assert has_element?(view, container, "Duración: 30 minutos")
      assert has_element?(view, container, "ARS 18.000,00")

      assert has_element?(
               view,
               ~s(#{container} [role="img"][aria-label="Color asignado a Evaluación inicial"][style="background-color: #123ABC"])
             )

      assert has_element?(view, "#{container} button:not([disabled])", "Editar")
      assert has_element?(view, "#{container} button:not([disabled])", "Desactivar")
      refute has_element?(view, "#{container} button", "Reactivar")
      refute has_element?(view, container, "#123ABC")
    end
  end

  test "rejects a tampered unsupported currency without mutating the catalog", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)
    open_new_type_modal(view)

    render_submit(view, "save_type", %{
      "consultation_type" => valid_new_type(currency: "USD", name: "Moneda inválida")
    })

    assert has_element?(view, "#new-consultation-type-modal")
    assert has_element?(view, ".pc-form-field-error", "Seleccione una moneda válida")
    assert has_element?(view, ~s(#new-consultation-type-currency[aria-invalid="true"]))
    assert rendered_catalog_item_count(view) == initial_item_count
    refute has_element?(view, "#consultation-types-table-view", "Moneda inválida")
  end

  test "duration is a calculated output that follows count changes and is not submitted", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)
    open_new_type_modal(view)

    assert has_element?(view, "label[for=new-consultation-type-duration]", "Duración")

    assert has_element?(
             view,
             ~s|output#new-consultation-type-duration[for="new-consultation-type-count"]:not([name]):not([contenteditable])|,
             "15 minutos"
           )

    refute has_element?(view, "input#new-consultation-type-duration")
    refute has_element?(view, "select#new-consultation-type-duration")
    refute has_element?(view, "textarea#new-consultation-type-duration")

    view
    |> form("#new-consultation-type-form",
      consultation_type: valid_new_type(interval_count: "3")
    )
    |> render_change()

    assert has_element?(view, "output#new-consultation-type-duration", "45 minutos")

    view
    |> form("#new-consultation-type-form",
      consultation_type: valid_new_type(interval_count: "")
    )
    |> render_change()

    assert has_element?(view, "output#new-consultation-type-duration", "—")

    view
    |> form("#new-consultation-type-form",
      consultation_type: valid_new_type(interval_count: "11")
    )
    |> render_change()

    assert has_element?(view, "output#new-consultation-type-duration", "—")

    render_submit(view, "save_type", %{
      "consultation_type" =>
        valid_new_type(name: "Duración derivada", interval_count: "2")
        |> Map.put("duration", "1")
    })

    assert rendered_catalog_item_count(view) == initial_item_count + 2

    assert has_element?(
             view,
             "#consultation-types-table-view tbody tr:last-child",
             "Duración: 30 minutos"
           )
  end

  test "a duplicate name creates a distinct catalog item", %{conn: conn} do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)
    open_new_type_modal(view)

    view
    |> form("#new-consultation-type-form",
      consultation_type:
        valid_new_type(
          name: "Control",
          exact_price_ars: "13.000",
          color: "#335577",
          interval_count: "2"
        )
    )
    |> render_submit()

    assert rendered_catalog_item_count(view) == initial_item_count + 2

    assert has_element?(
             view,
             "#consultation-types-table-view tbody tr:last-child",
             "Control"
           )

    assert has_element?(
             view,
             "#consultation-types-table-view tbody tr:last-child",
             "ARS 13.000,00"
           )

    assert has_element?(
             view,
             "#consultation-type-018f4a5b-0d62-7a44-8e32-2f608bfcb002",
             "ARS 12.000,00"
           )
  end

  test "blank and malformed fields show accessible errors without changing the catalog", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    initial_item_count = rendered_catalog_item_count(view)
    open_new_type_modal(view)

    view
    |> form("#new-consultation-type-form",
      consultation_type: %{
        name: "   ",
        exact_price_ars: "not-a-price",
        color: "invalid",
        interval_count: "0"
      }
    )
    |> render_submit()

    assert has_element?(view, "#new-consultation-type-modal")
    assert has_element?(view, "#new-consultation-type-errors[role=alert]")
    assert has_element?(view, ".pc-form-field-error", "Ingrese un nombre")
    assert has_element?(view, ".pc-form-field-error", "Ingrese un precio válido en ARS")
    assert has_element?(view, ".pc-form-field-error", "Seleccione un color válido")
    assert has_element?(view, ".pc-form-field-error", "La cantidad debe estar entre 1 y 10")

    for field <- ~w(name price color count) do
      assert has_element?(
               view,
               ~s(#new-consultation-type-#{field}[aria-invalid="true"][aria-describedby*="new-consultation-type-errors"])
             )
    end

    assert rendered_catalog_item_count(view) == initial_item_count
  end

  test "all exact server-side field bounds reject atomically", %{conn: conn} do
    invalid_cases = [
      {[name: String.duplicate("a", 33)], "El nombre admite hasta 32 caracteres"},
      {[exact_price_ars: "-0,01"], "El precio no puede ser negativo"},
      {[exact_price_ars: "10,001"], "El precio admite hasta dos decimales"},
      {[exact_price_ars: "18.00,00"], "Ingrese un precio válido en ARS"},
      {[exact_price_ars: "1.234.56"], "Ingrese un precio válido en ARS"},
      {[exact_price_ars: "NaN"], "Ingrese un precio válido en ARS"},
      {[exact_price_ars: "Infinity"], "Ingrese un precio válido en ARS"},
      {[color: "#12345G"], "Seleccione un color válido"},
      {[interval_count: "11"], "La cantidad debe estar entre 1 y 10"},
      {[interval_count: "1.5"], "La cantidad debe estar entre 1 y 10"}
    ]

    for {overrides, expected_error} <- invalid_cases do
      {:ok, view, _html} = live(conn, @professional_configuration_path)
      initial_item_count = rendered_catalog_item_count(view)
      open_new_type_modal(view)

      view
      |> form("#new-consultation-type-form",
        consultation_type: valid_new_type(overrides)
      )
      |> render_submit()

      assert has_element?(view, "#new-consultation-type-modal")
      assert has_element?(view, ".pc-form-field-error", expected_error)
      assert rendered_catalog_item_count(view) == initial_item_count
    end
  end

  test "the effective count maximum follows the applied interval and prevents long durations", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, @professional_configuration_path)
    open_new_type_modal(view)

    assert has_element?(
             view,
             ~s(#new-consultation-type-count[type="number"][min="1"][max="10"][step="1"])
           )

    assert has_element?(
             view,
             "output#new-consultation-type-duration",
             "15 minutos"
           )

    view
    |> element("#new-consultation-type-modal button", "Cancelar")
    |> render_click()

    view
    |> form("#agenda-interval-form", interval_minutes: "60")
    |> render_submit()

    assert has_element?(view, "#current-agenda-interval", "60 minutos")
    open_new_type_modal(view)

    assert has_element?(
             view,
             ~s(#new-consultation-type-count[type="number"][min="1"][max="4"][step="1"])
           )

    assert has_element?(
             view,
             "output#new-consultation-type-duration",
             "60 minutos"
           )

    initial_item_count = rendered_catalog_item_count(view)

    view
    |> form("#new-consultation-type-form",
      consultation_type: valid_new_type(name: "Duración inválida", interval_count: "5")
    )
    |> render_submit()

    assert has_element?(view, ".pc-form-field-error", "La cantidad debe estar entre 1 y 4")
    assert rendered_catalog_item_count(view) == initial_item_count
    refute has_element?(view, "#consultation-types-table-view", "Duración: 300 minutos")

    view
    |> form("#new-consultation-type-form",
      consultation_type: valid_new_type(name: "Duración máxima", interval_count: "4")
    )
    |> render_submit()

    assert rendered_catalog_item_count(view) == initial_item_count + 2

    assert has_element?(
             view,
             "#consultation-types-table-view tbody tr:last-child",
             "Duración: 240 minutos"
           )
  end

  test "an unavailable catalog shows one complete failure state and no modules", %{conn: conn} do
    Application.put_env(
      :origen,
      :consultation_type_catalog_adapter,
      UnavailableCatalogAdapter
    )

    {:ok, view, _html} = live(conn, @professional_configuration_path)

    assert has_element?(
             view,
             "#configuration-load-error[role=alert]",
             "No se pudo cargar la configuración"
           )

    refute has_element?(view, "#agenda-interval-heading")
    refute has_element?(view, "#consultation-types-heading")
    refute has_element?(view, "table")
    refute has_element?(view, ~s([aria-label="Vista móvil del catálogo"]))
  end

  defp open_new_type_modal(view) do
    view
    |> element(~s(button[phx-click="open_new_type"]), "Nuevo tipo de consulta")
    |> render_click()
  end

  defp open_edit_type_modal(view, type) do
    view
    |> element(
      ~s(#consultation-type-#{type.id} button[phx-click="open_edit_type"][phx-value-id="#{type.id}"]),
      "Editar"
    )
    |> render_click()
  end

  defp use_reactivation_catalog do
    Application.put_env(
      :origen,
      :consultation_type_catalog_adapter,
      ReactivationCatalogAdapter
    )
  end

  defp show_inactive(view) do
    view
    |> form("#consultation-types-filter", show_inactive: "true")
    |> render_change()
  end

  defp open_incompatible_reactivation(view) do
    show_inactive(view)

    view
    |> element(
      ~s(#consultation-type-#{@incompatible_inactive_type.id} button[phx-click="reactivate_type"]),
      "Reactivar"
    )
    |> render_click()
  end

  defp deactivation_dialog_id(type), do: "deactivate-consultation-type-#{type.id}"

  defp deactivation_trigger_selector(type, presentation) do
    "#deactivate-consultation-type-#{type.id}-#{presentation}"
  end

  defp edit_type_params(type, overrides) do
    %{
      "name" => type.name,
      "currency" => "ARS",
      "exact_price_ars" => String.replace_prefix(type.price, "ARS ", ""),
      "color" => type.color,
      "interval_count" => Integer.to_string(type.count)
    }
    |> Map.merge(Map.new(overrides, fn {key, value} -> {to_string(key), value} end))
  end

  defp valid_new_type(overrides) do
    %{
      "name" => "Consulta nueva",
      "currency" => "ARS",
      "exact_price_ars" => "20.000,00",
      "color" => "#0A7C86",
      "interval_count" => "1"
    }
    |> Map.merge(Map.new(overrides, fn {key, value} -> {to_string(key), value} end))
  end

  defp rendered_catalog_item_count(view) do
    ~r/\sid="consultation-type-(?:mobile-)?[0-9a-f-]+"/
    |> Regex.scan(render(view))
    |> length()
  end

  defp rendered_element_count(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> LazyHTML.to_tree()
    |> length()
  end
end

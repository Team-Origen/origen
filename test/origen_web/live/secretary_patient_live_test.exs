defmodule OrigenWeb.SecretaryPatientLiveTest do
  use OrigenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @path "/secretaria/pacientes"

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)
    :ok
  end

  describe "mount authorization" do
    test "redirects unauthenticated visitors to the home page" do
      assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), @path)
    end

    test "redirects internal roles without explicit operational access (administrator and professional)" do
      for role <- [:professional, :administrator] do
        conn =
          build_conn()
          |> log_in_internal_account(insert_active_internal_account!(role))

        assert {:error, {:redirect, %{to: "/"}}} = live(conn, @path)
      end
    end

    test "secretary mounts the patient search view" do
      conn =
        build_conn()
        |> log_in_internal_account(insert_active_internal_account!(:secretary))

      assert {:ok, _view, html} = live(conn, @path)
      assert html =~ "Búsqueda de pacientes"
      assert html =~ "Buscar persona"
    end
  end

  describe "document search" do
    test "redirects safely when secretary role is revoked after mount" do
      account = insert_active_internal_account!(:secretary)
      conn = build_conn() |> log_in_internal_account(account)
      {:ok, view, _html} = live(conn, @path)

      Repo.query!("UPDATE internal_accounts SET role = 'administrator' WHERE id = $1", [
        account.id
      ])

      render_submit(view, "search", %{
        "search" => %{"document_type" => "dni", "document_number" => "37000111"}
      })

      assert_redirect(view, "/")
      assert Repo.aggregate(Persona, :count) == 0
    end

    test "searching an existing persona renders the patient summary" do
      {:ok, _} =
        Patients.complete_profile("carlos@example.test", %{
          first_name: "Carlos",
          last_name: "López",
          document_type: "dni",
          document_number: "35.987.654",
          birthdate: ~D[1988-07-20],
          phone: "+5491144332211"
        })

      {:ok, view, _html} = live(secretary_conn(), @path)

      html =
        view
        |> form("#persona-search-form",
          search: %{"document_type" => "dni", "document_number" => "35.987.654"}
        )
        |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert html =~ "Carlos López"
      assert has_element?(view, "#patient-summary-document", "DNI 35987654")
      assert has_element?(view, "#patient-summary-profile-state", "Completado")
      assert has_element?(view, "#patient-summary-phone", "+5491144332211")
      assert has_element?(view, "#patient-summary-phone-verified", "Teléfono no verificado")

      assert has_element?(
               view,
               ~s(button#start-assisted-booking[phx-click="start_assisted_booking"]),
               "Iniciar Reserva Asistida"
             )
    end

    test "searching an unknown document shows the assisted registration form" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      html =
        view
        |> form("#persona-search-form",
          search: %{"document_type" => "dni", "document_number" => "37000111"}
        )
        |> render_submit()

      assert html =~ "No encontramos una persona con el documento indicado"
      assert has_element?(view, "#persona-registration-section")
      assert has_element?(view, "#assisted-registration-form")
      refute has_element?(view, "#patient-summary-section")

      assert has_element?(
               view,
               ~s(input[type="hidden"][name="registration[document_type]"][value="dni"])
             )

      assert has_element?(
               view,
               ~s(input[type="hidden"][name="registration[document_number]"][value="37000111"])
             )

      assert has_element?(view, "#assisted-registration-form p strong", "DNI 37000111")

      for label <- [
            "Nombres",
            "Apellidos",
            "Fecha de nacimiento",
            "Teléfono",
            "Correo de contacto (opcional)",
            "Género"
          ] do
        assert has_element?(view, "#assisted-registration-form label", label)
      end

      assert has_element?(view, "#assisted-registration-form button", "Registrar persona")
    end

    test "invalid searches keep real-time feedback without leaving the search form" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      html =
        view
        |> form("#persona-search-form", search: %{"document_number" => ""})
        |> render_submit()

      assert html =~ "no puede estar en blanco"
      refute has_element?(view, "#persona-registration-section")
      refute has_element?(view, "#patient-summary-section")
    end
  end

  describe "assisted registration" do
    for scenario <- [
          :no_search,
          :changed_dni,
          :changed_type,
          :reset,
          :edited_search,
          :invalid_search,
          :new_search
        ] do
      @scenario scenario
      test "rejects forged or stale registration after #{@scenario}" do
        {:ok, view, _html} = live(secretary_conn(), @path)
        document = %{"document_type" => "dni", "document_number" => "37000111"}

        unless @scenario == :no_search do
          render_submit(view, "search", %{"search" => document})
        end

        case @scenario do
          :reset ->
            render_click(view, "new_search")

          :edited_search ->
            render_change(view, "validate_search", %{
              "search" => Map.put(document, "document_number", "37000222")
            })

          :invalid_search ->
            render_submit(view, "search", %{"search" => Map.put(document, "document_number", "")})

          :new_search ->
            render_submit(view, "search", %{
              "search" => Map.put(document, "document_number", "37000222")
            })

          _ ->
            :ok
        end

        submitted_document =
          case @scenario do
            :changed_dni -> Map.put(document, "document_number", "37000333")
            :changed_type -> Map.put(document, "document_type", "passport")
            _ -> document
          end

        attrs =
          Map.merge(submitted_document, %{
            "first_name" => "Ana",
            "last_name" => "Torres",
            "birthdate" => "1990-03-05",
            "phone" => "+5491155554444",
            "gender" => "femenino"
          })

        render_change(view, "validate_registration", %{"registration" => attrs})
        render_submit(view, "register", %{"registration" => attrs})

        refute has_element?(view, "#patient-summary-section")
        assert Repo.aggregate(Persona, :count) == 0
        assert Repo.aggregate(PatientProfile, :count) == 0
      end
    end

    test "registering a new persona creates the identity and shows summary without personal account" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      refute has_element?(view, ~s(select[name="registration[gender]"][required]))

      html =
        view
        |> form("#assisted-registration-form",
          registration: %{
            "first_name" => "Ana",
            "last_name" => "Torres",
            "birthdate" => "1990-03-05",
            "phone" => "+5491155554444",
            "email" => ""
          }
        )
        |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert html =~ "Ana Torres"
      assert html =~ "Persona registrada correctamente."
      assert has_element?(view, "#patient-summary-document", "DNI 37000111")
      assert has_element?(view, "#patient-summary-profile-state", "Completado")
      assert has_element?(view, "#patient-summary-phone", "+5491155554444")
      assert has_element?(view, "#patient-summary-email", "No declarado")
      refute has_element?(view, "#assisted-registration-form")

      persona = Repo.get_by!(Persona, document_type: "dni", document_number: "37000111")
      profile = Repo.get_by!(PatientProfile, persona_id: persona.id)

      assert persona.first_name == "Ana"
      assert persona.last_name == "Torres"
      assert profile.state == "completed"
      assert profile.phone == "+5491155554444"
      assert profile.email == nil
      assert profile.contact_email == nil
    end

    test "registration rechecks authorization after an unsuccessful search" do
      account = insert_active_internal_account!(:secretary)
      {:ok, view, _html} = live(build_conn() |> log_in_internal_account(account), @path)

      render_submit(view, "search", %{
        "search" => %{"document_type" => "dni", "document_number" => "37000111"}
      })

      Repo.query!("UPDATE internal_accounts SET role = 'administrator' WHERE id = $1", [
        account.id
      ])

      view
      |> form("#assisted-registration-form",
        registration: %{
          "first_name" => "Ana",
          "last_name" => "Torres",
          "birthdate" => "1990-03-05",
          "phone" => "+5491155554444"
        }
      )
      |> render_submit()

      assert_redirect(view, "/")
      assert Repo.aggregate(Persona, :count) == 0
      assert Repo.aggregate(PatientProfile, :count) == 0
    end

    test "successful registration and found searches cannot authorize another registration" do
      {:ok, view, _html} = live(secretary_conn(), @path)
      document = %{"document_type" => "passport", "document_number" => "AB123456"}
      render_submit(view, "search", %{"search" => document})

      attrs =
        Map.merge(document, %{
          "first_name" => "Ana",
          "last_name" => "Torres",
          "birthdate" => "1990-03-05",
          "phone" => "+5491155554444"
        })

      render_submit(view, "register", %{"registration" => attrs})
      assert has_element?(view, "#patient-summary-document", "Pasaporte AB123456")

      forged = Map.put(attrs, "document_number", "AB999999")
      render_submit(view, "register", %{"registration" => forged})
      render_submit(view, "search", %{"search" => document})
      assert has_element?(view, "#patient-summary-section")
      render_submit(view, "register", %{"registration" => forged})
      assert Repo.aggregate(Persona, :count) == 1
      assert Repo.aggregate(PatientProfile, :count) == 1
    end

    test "registering with optional contact email stores it and displays it in summary" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000222"}
      )
      |> render_submit()

      html =
        view
        |> form("#assisted-registration-form",
          registration: %{
            "first_name" => "Laura",
            "last_name" => "Paz",
            "birthdate" => "1992-06-15",
            "phone" => "+5491166778899",
            "email" => "laura.paz@example.test",
            "gender" => "femenino"
          }
        )
        |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert html =~ "Laura Paz"
      assert has_element?(view, "#patient-summary-email", "laura.paz@example.test")

      persona = Repo.get_by!(Persona, document_type: "dni", document_number: "37000222")
      profile = Repo.get_by!(PatientProfile, persona_id: persona.id)

      assert profile.contact_email == "laura.paz@example.test"
      assert profile.email == nil
    end

    test "submitting duplicate DNI retains form and displays error" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      # Search DNI 37000111 when it does not exist yet
      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      # Concurrently insert a persona with DNI 37000111
      %Persona{}
      |> Persona.changeset(%{
        first_name: "Existente",
        last_name: "Paciente",
        document_type: "dni",
        document_number: "37000111",
        birthdate: ~D[1980-01-01]
      })
      |> Repo.insert!()

      # Submit the registration form with the concurrent collision
      html =
        view
        |> form("#assisted-registration-form",
          registration: %{
            "first_name" => "Duplicado",
            "last_name" => "Intento",
            "birthdate" => "1990-03-05",
            "phone" => "+5491155554444",
            "gender" => "masculino"
          }
        )
        |> render_submit()

      assert has_element?(view, "#assisted-registration-form")
      assert html =~ "ya ha sido registrado"
      refute has_element?(view, "#patient-summary-section")
      assert Repo.aggregate(Persona, :count) == 1
    end

    test "submitting invalid registration data keeps the form with accessible errors" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      html =
        view
        |> form("#assisted-registration-form",
          registration: %{
            "first_name" => "",
            "last_name" => "",
            "birthdate" => "",
            "phone" => "",
            "gender" => ""
          }
        )
        |> render_submit()

      assert has_element?(view, "#assisted-registration-form")
      assert html =~ "no puede estar en blanco"
      refute has_element?(view, "#patient-summary-section")
      assert Repo.aggregate(Persona, :count) == 0
    end

    test "a new search resets the registration flow" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      assert has_element?(view, "#assisted-registration-form")

      view
      |> element("button", "Nueva búsqueda")
      |> render_click()

      refute has_element?(view, "#assisted-registration-form")
      refute has_element?(view, "#patient-summary-section")
      assert has_element?(view, "#persona-search-form")
    end
  end

  describe "assisted booking entry point" do
    test "the booking notice is shown until the assisted flow lands in #68" do
      {:ok, view, _html} = live(secretary_conn(), @path)

      view
      |> form("#persona-search-form",
        search: %{"document_type" => "dni", "document_number" => "37000111"}
      )
      |> render_submit()

      view
      |> form("#assisted-registration-form",
        registration: %{
          "first_name" => "Ana",
          "last_name" => "Torres",
          "birthdate" => "1990-03-05",
          "phone" => "+5491155554444",
          "gender" => "femenino"
        }
      )
      |> render_submit()

      refute has_element?(view, "#assisted-booking-notice")

      view
      |> element("#start-assisted-booking", "Iniciar Reserva Asistida")
      |> render_click()

      assert has_element?(
               view,
               "#assisted-booking-notice",
               "La reserva asistida estará disponible próximamente."
             )
    end
  end

  defp secretary_conn do
    build_conn()
    |> log_in_internal_account(insert_active_internal_account!(:secretary))
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

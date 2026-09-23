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

    test "redirects internal roles outside secretary and administrator" do
      conn =
        build_conn()
        |> log_in_internal_account(insert_active_internal_account!(:professional))

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, @path)
    end

    test "secretary and administrator mount the patient search view" do
      for role <- [:secretary, :administrator] do
        conn =
          build_conn()
          |> log_in_internal_account(insert_active_internal_account!(role))

        assert {:ok, _view, html} = live(conn, @path)
        assert html =~ "Búsqueda de pacientes"
        assert html =~ "Buscar persona"
      end
    end
  end

  describe "document search" do
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

      for label <- ["Nombres", "Apellidos", "Fecha de nacimiento", "Teléfono", "Género"] do
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
    test "registering a new persona creates the identity and shows the summary" do
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
            "first_name" => "Ana",
            "last_name" => "Torres",
            "birthdate" => "1990-03-05",
            "phone" => "+5491155554444",
            "gender" => "femenino"
          }
        )
        |> render_submit()

      assert has_element?(view, "#patient-summary-section")
      assert html =~ "Ana Torres"
      assert html =~ "Persona registrada correctamente."
      assert has_element?(view, "#patient-summary-document", "DNI 37000111")
      assert has_element?(view, "#patient-summary-profile-state", "Pendiente de completar")
      assert has_element?(view, "#patient-summary-phone", "+5491155554444")
      refute has_element?(view, "#assisted-registration-form")

      persona = Repo.get_by!(Persona, document_type: "dni", document_number: "37000111")
      profile = Repo.get_by!(PatientProfile, persona_id: persona.id)

      assert persona.first_name == "Ana"
      assert persona.last_name == "Torres"
      assert profile.state == "pending_completion"
      assert profile.phone == "+5491155554444"
      assert profile.email == "asistido-persona-#{persona.id}@origen.local"
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

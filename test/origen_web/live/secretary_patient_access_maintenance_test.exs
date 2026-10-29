defmodule OrigenWeb.SecretaryPatientAccessMaintenanceTest do
  use OrigenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Origen.PatientAccess.MagicLink
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @path "/secretaria/pacientes"

  @assisted_attrs %{
    first_name: "Lucía",
    last_name: "Vázquez",
    document_type: "dni",
    document_number: "39.111.222",
    birthdate: ~D[1994-08-12],
    phone: "+5491166667777",
    email: nil
  }

  setup do
    Repo.delete_all(MagicLink)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    secretary_account = insert_active_internal_account!(:secretary)
    conn = build_conn() |> log_in_internal_account(secretary_account)

    %{
      conn: conn,
      secretary_account: secretary_account
    }
  end

  describe "patient access email maintenance UI" do
    test "renders 'Sin acceso web vinculado' and link button when patient has email: nil", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      {:ok, %{persona: persona}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      assert has_element?(view, "#patient-summary-access-email", "Sin acceso web vinculado")
      assert has_element?(view, "#btn-open-link-access", "Vincular correo de acceso")
      refute has_element?(view, "#btn-open-replace-access")
      refute has_element?(view, "#link-access-section")
    end

    test "opening and cancelling the link access form", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      {:ok, %{persona: persona}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      # Open form
      view
      |> element("#btn-open-link-access")
      |> render_click()

      assert has_element?(view, "#link-access-section")
      assert has_element?(view, "#link-access-form")

      # Cancel form
      view
      |> element("#cancel-link-access")
      |> render_click()

      refute has_element?(view, "#link-access-section")
      assert has_element?(view, "#btn-open-link-access")
    end

    test "real-time validation on link form", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      {:ok, %{persona: persona}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      view
      |> element("#btn-open-link-access")
      |> render_click()

      html =
        view
        |> form("#link-access-form", access: %{"email" => "invalido"})
        |> render_change()

      assert html =~ "Debe ser un correo electrónico válido"
    end

    test "submitting valid link access updates profile, shows feedback and dispatches magic link",
         %{
           conn: conn,
           secretary_account: secretary_account
         } do
      {:ok, %{persona: persona}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      view
      |> element("#btn-open-link-access")
      |> render_click()

      new_email = "lucia.vazquez@example.test"

      view
      |> form("#link-access-form", access: %{"email" => new_email})
      |> render_submit()

      # Assert feedback
      assert has_element?(view, "#access-feedback", "Correo de acceso vinculado exitosamente")
      assert has_element?(view, "#patient-summary-access-email", new_email)

      # Button now switches to replace
      assert has_element?(view, "#btn-open-replace-access", "Reemplazar correo de acceso")
      refute has_element?(view, "#btn-open-link-access")
      refute has_element?(view, "#link-access-section")

      # Assert email dispatch
      assert_email_sent(fn email ->
        email.to == [{"", new_email}] and email.html_body =~ "/access/verify?token="
      end)
    end

    test "submitting link access with email in use shows reactive error alert", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      # Existing patient with email
      {:ok, _} =
        Patients.complete_profile("ocupado@example.test", %{
          first_name: "Otro",
          last_name: "Paciente",
          document_type: "dni",
          document_number: "22.333.444",
          birthdate: ~D[1985-01-01],
          phone: "+5491122221111"
        })

      {:ok, %{persona: persona}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      view
      |> element("#btn-open-link-access")
      |> render_click()

      view
      |> form("#link-access-form", access: %{"email" => "ocupado@example.test"})
      |> render_submit()

      assert has_element?(
               view,
               "#link-access-error",
               "Este correo ya está registrado por otra cuenta de paciente."
             )

      assert has_element?(view, "#patient-summary-access-email", "Sin acceso web vinculado")
    end

    test "renders current access email and replace button when patient already has email", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, _} =
        Patients.link_patient_access_email(
          profile,
          "titular@example.test",
          secretary_account.id
        )

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      assert has_element?(view, "#patient-summary-access-email", "titular@example.test")
      assert has_element?(view, "#btn-open-replace-access", "Reemplazar correo de acceso")
      refute has_element?(view, "#btn-open-link-access")
    end

    test "opening and cancelling the replace access form", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      {:ok, _} =
        Patients.link_patient_access_email(
          profile,
          "titular@example.test",
          secretary_account.id
        )

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      view
      |> element("#btn-open-replace-access")
      |> render_click()

      assert has_element?(view, "#replace-access-section")
      assert has_element?(view, "#replace-access-form")

      view
      |> element("#cancel-replace-access")
      |> render_click()

      refute has_element?(view, "#replace-access-section")
      assert has_element?(view, "#btn-open-replace-access")
    end

    test "submitting valid replace access updates email, invalidates prior link and shows feedback",
         %{
           conn: conn,
           secretary_account: secretary_account
         } do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      old_email = "antiguo@example.test"
      new_email = "renovado@example.test"

      {:ok, _} =
        Patients.link_patient_access_email(
          profile,
          old_email,
          secretary_account.id
        )

      # Drain old email
      assert_email_sent(fn email -> email.to == [{"", old_email}] end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      view
      |> element("#btn-open-replace-access")
      |> render_click()

      view
      |> form("#replace-access-form",
        access: %{
          "new_email" => new_email,
          "reason" => "Pérdida de acceso a cuenta anterior solicitada presencialmente"
        }
      )
      |> render_submit()

      assert has_element?(view, "#access-feedback", "Correo de acceso reemplazado exitosamente")
      assert has_element?(view, "#patient-summary-access-email", new_email)

      # Assert magic link sent to new email
      assert_email_sent(fn email -> email.to == [{"", new_email}] end)
    end

    test "submitting replace access with same email or empty reason shows error alert", %{
      conn: conn,
      secretary_account: secretary_account
    } do
      {:ok, %{persona: persona, profile: profile}} =
        Patients.register_absent_patient(@assisted_attrs, secretary_account.id)

      current_email = "actual@example.test"

      {:ok, _} =
        Patients.link_patient_access_email(
          profile,
          current_email,
          secretary_account.id
        )

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#persona-search-form",
        search: %{
          "document_type" => persona.document_type,
          "document_number" => persona.document_number
        }
      )
      |> render_submit()

      view
      |> element("#btn-open-replace-access")
      |> render_click()

      # Same email
      view
      |> form("#replace-access-form",
        access: %{"new_email" => current_email, "reason" => "Motivo"}
      )
      |> render_submit()

      assert has_element?(
               view,
               "#replace-access-error",
               "El nuevo correo no puede ser igual al correo actual."
             )
    end
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

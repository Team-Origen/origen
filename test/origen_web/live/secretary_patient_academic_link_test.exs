defmodule OrigenWeb.SecretaryPatientAcademicLinkTest do
  use OrigenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Origen.PatientAccess.MagicLink
  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @path "/secretaria/pacientes"

  @patient_attrs %{
    first_name: "Ramiro",
    last_name: "Suárez",
    document_type: "dni",
    document_number: "40.222.333",
    birthdate: ~D[1990-03-03],
    phone: "+5491177778888",
    email: nil
  }

  setup do
    previous = Application.get_env(:origen, :academic_patient_access)

    on_exit(fn -> Application.put_env(:origen, :academic_patient_access, previous) end)

    Repo.delete_all(MagicLink)
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)

    Application.put_env(:origen, :academic_patient_access,
      enabled: true,
      isolated_fictional_data_confirmed: true,
      public_origin: "https://evaluation.example.test"
    )

    secretary_account = insert_active_internal_account!(:secretary)
    conn = build_conn() |> log_in_internal_account(secretary_account)

    {:ok, %{persona: persona, profile: profile}} =
      Patients.register_absent_patient(@patient_attrs, secretary_account.id)

    %{conn: conn, persona: persona, profile: profile, secretary_account: secretary_account}
  end

  defp search_patient(view, persona) do
    view
    |> form("#persona-search-form",
      search: %{
        "document_type" => persona.document_type,
        "document_number" => persona.document_number
      }
    )
    |> render_submit()
  end

  defp submit_link(view, email) do
    view
    |> form("#link-access-form", access: %{"email" => email})
    |> render_submit()
  end

  test "link success with academic mode shows transient copy/open result and keeps email delivery",
       %{conn: conn, persona: persona} do
    {:ok, view, _html} = live(conn, @path)
    search_patient(view, persona)
    view |> element("#btn-open-link-access") |> render_click()

    submit_link(view, "ramiro.suarez@example.test")

    assert has_element?(view, "#access-feedback", "Correo de acceso vinculado exitosamente")
    assert has_element?(view, "#secretary-academic-access-url[readonly]")
    assert has_element?(view, "#copy-secretary-academic-access", "Copiar enlace")
    assert has_element?(view, "#secretary-academic-link", "Abrir acceso")

    [url] =
      view
      |> element("#secretary-academic-access-url")
      |> render()
      |> LazyHTML.from_document()
      |> LazyHTML.query("input")
      |> LazyHTML.attribute("value")

    assert String.starts_with?(
             url,
             "https://evaluation.example.test/paciente/acceso/verificar?token="
           )

    assert_email_sent()
  end

  test "link success without academic mode keeps the current feedback with no link block",
       %{conn: conn, persona: persona} do
    Application.put_env(:origen, :academic_patient_access,
      enabled: false,
      isolated_fictional_data_confirmed: false,
      public_origin: nil
    )

    {:ok, view, _html} = live(conn, @path)
    search_patient(view, persona)
    view |> element("#btn-open-link-access") |> render_click()

    submit_link(view, "ramiro.suarez@example.test")

    assert has_element?(view, "#access-feedback", "Correo de acceso vinculado exitosamente")
    refute has_element?(view, "#secretary-academic-access")
    assert_email_sent()
  end

  test "failed linking shows the current error with no link block",
       %{conn: conn, persona: persona, secretary_account: secretary_account} do
    {:ok, %{profile: other_profile}} =
      Patients.register_absent_patient(
        %{@patient_attrs | document_number: "41.333.444", first_name: "Otra"},
        secretary_account.id
      )

    {:ok, _} =
      Patients.link_patient_access_email(
        other_profile,
        "ocupado@example.test",
        secretary_account.id
      )

    {:ok, view, _html} = live(conn, @path)
    search_patient(view, persona)
    view |> element("#btn-open-link-access") |> render_click()

    submit_link(view, "ocupado@example.test")

    assert has_element?(view, "#link-access-error")
    refute has_element?(view, "#secretary-academic-access")
  end

  test "the transient result is not shown after remounting the screen",
       %{conn: conn, persona: persona} do
    {:ok, view, _html} = live(conn, @path)
    search_patient(view, persona)
    view |> element("#btn-open-link-access") |> render_click()

    submit_link(view, "ramiro.suarez@example.test")

    assert has_element?(view, "#secretary-academic-access-url")

    {:ok, fresh_view, _html} = live(conn, @path)
    search_patient(fresh_view, persona)
    refute has_element?(fresh_view, "#secretary-academic-access")
  end

  test "link and replace domain results carry the transient URL when academic mode is enabled",
       %{profile: profile, secretary_account: secretary_account} do
    {:ok, %{access_url: link_url}} =
      Patients.link_patient_access_email(profile, "viejo@example.test", secretary_account.id)

    assert String.starts_with?(
             link_url,
             "https://evaluation.example.test/paciente/acceso/verificar?token="
           )

    {:ok, %{access_url: replace_url, outcome: :replaced}} =
      Patients.replace_patient_access_email(
        profile,
        "nuevo@example.test",
        secretary_account.id,
        "Cambio de casilla"
      )

    assert String.starts_with?(
             replace_url,
             "https://evaluation.example.test/paciente/acceso/verificar?token="
           )
  end

  test "searching another patient clears the previous academic link",
       %{conn: conn, persona: persona, secretary_account: secretary_account} do
    {:ok, %{persona: persona_b}} =
      Patients.register_absent_patient(
        %{@patient_attrs | document_number: "42.444.555", first_name: "Bruno"},
        secretary_account.id
      )

    {:ok, view, _html} = live(conn, @path)
    search_patient(view, persona)
    view |> element("#btn-open-link-access") |> render_click()

    submit_link(view, "ramiro.suarez@example.test")

    assert has_element?(view, "#secretary-academic-access-url")

    search_patient(view, persona_b)

    refute has_element?(view, "#secretary-academic-access-url")
  end

  test "replace access button opens the flow and shows the academic result",
       %{conn: conn, persona: persona, profile: profile, secretary_account: secretary_account} do
    {:ok, _} =
      Patients.link_patient_access_email(profile, "viejo@example.test", secretary_account.id)

    {:ok, view, _html} = live(conn, @path)
    search_patient(view, persona)

    assert has_element?(view, "#btn-open-replace-access", "Reemplazar correo de acceso")

    view |> element("#btn-open-replace-access") |> render_click()

    assert has_element?(view, "#replace-access-section")

    view
    |> form("#replace-access-form",
      access: %{"new_email" => "nuevo@example.test", "reason" => "Cambio de casilla"}
    )
    |> render_submit()

    assert has_element?(view, "#access-feedback", "Correo de acceso reemplazado exitosamente")
    assert has_element?(view, "#secretary-academic-access-url[readonly]")
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

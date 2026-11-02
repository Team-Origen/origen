defmodule OrigenWeb.PatientProfileCompletionLiveTest do
  use OrigenWeb.LiveViewCase

  alias Origen.Patients
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @email "paciente_profile_edit@example.test"

  setup do
    Repo.delete_all(PatientProfile)
    Repo.delete_all(Persona)
    :ok
  end

  test "rejects anonymous access to the profile editing route", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/", flash: %{"error" => message}}}} =
             live(conn, ~p"/patient/profile/complete")

    assert message == "La edición autónoma del perfil no está habilitada."
    assert Repo.aggregate(PatientProfile, :count) == 0
  end

  test "rejects an authenticated patient attempt without changing identity data", %{conn: conn} do
    attrs = %{
      first_name: "Carlos",
      last_name: "López",
      document_type: "dni",
      document_number: "35987654",
      birthdate: ~D[1988-07-20],
      phone: "+5491144332211"
    }

    {:ok, %{profile: profile}} = Patients.complete_profile(@email, attrs)

    authed_conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:patient_email, @email)
      |> Plug.Conn.put_session(
        :patient_authenticated_at,
        DateTime.to_iso8601(DateTime.utc_now())
      )

    assert {:error, {:redirect, %{to: "/", flash: %{"error" => message}}}} =
             live(authed_conn, ~p"/patient/profile/complete")

    assert message == "La edición autónoma del perfil no está habilitada."

    unchanged = Repo.get!(PatientProfile, profile.id)
    assert unchanged.persona_id == profile.persona_id
    assert unchanged.email == @email
    assert Repo.get!(Persona, profile.persona_id).document_number == "35987654"
  end
end

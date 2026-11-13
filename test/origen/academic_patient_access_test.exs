defmodule Origen.AcademicPatientAccessTest do
  use Origen.DataCase

  import Swoosh.TestAssertions
  alias Origen.{PatientAccess, Patients}

  setup do
    previous = Application.get_env(:origen, :academic_patient_access)
    on_exit(fn -> Application.put_env(:origen, :academic_patient_access, previous) end)
    {:ok, _} = Patients.get_or_create_profile("academic@example.test")
    :ok
  end

  defp enable(overrides \\ []) do
    Application.put_env(
      :origen,
      :academic_patient_access,
      Keyword.merge(
        [
          enabled: true,
          isolated_fictional_data_confirmed: true,
          public_origin: "https://evaluation.example.test"
        ],
        overrides
      )
    )
  end

  defp token(url),
    do: url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("token")

  test "default-off and unconfirmed configurations cannot expose tokens" do
    Application.delete_env(:origen, :academic_patient_access)

    assert {:error, :disabled} =
             PatientAccess.request_academic_magic_link("academic@example.test")

    enable(isolated_fictional_data_confirmed: false)

    assert {:error, :disabled} =
             PatientAccess.request_academic_magic_link("academic@example.test")

    for origin <- [
          "http://evaluation.example.test",
          "https://localhost",
          "https://127.0.0.1",
          "https://user:pass@example.test",
          "https://example.test/path",
          "https://example.test?x=1"
        ] do
      enable(public_origin: origin)

      assert {:error, :disabled} =
               PatientAccess.request_academic_magic_link("academic@example.test")
    end

    refute_email_sent()
  end

  test "academic issuance uses normal single-use tokens without contacting mailer" do
    enable()
    assert {:ok, url} = PatientAccess.request_academic_magic_link(" ACADEMIC@example.test ")

    assert String.starts_with?(
             url,
             "https://evaluation.example.test/paciente/acceso/verificar?token="
           )

    refute_email_sent()
    assert {:ok, %{email: "academic@example.test"}} = PatientAccess.consume_magic_link(token(url))
    assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link(token(url))
  end

  test "academic issuance retains replacement invalidation and expiry" do
    enable()
    assert {:ok, old} = PatientAccess.request_academic_magic_link("academic@example.test")
    assert {:ok, current} = PatientAccess.request_academic_magic_link("academic@example.test")
    assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link(token(old))

    assert {:error, :invalid_or_expired} =
             PatientAccess.consume_magic_link(token(current),
               now: DateTime.add(DateTime.utc_now(), 901)
             )
  end

  test "unknown addresses do not create patients or access links" do
    enable()
    assert {:ok, nil} = PatientAccess.request_academic_magic_link("unknown@example.test")
    assert {:ok, nil} = PatientAccess.request_academic_magic_link(nil)
    refute Origen.Repo.get_by(Origen.Patients.PatientProfile, email: "unknown@example.test")
    refute Origen.Repo.get_by(Origen.PatientAccess.MagicLink, email: "unknown@example.test")
    refute_email_sent()
  end

  test "normal email API remains opaque even when academic mode is enabled" do
    enable()
    assert {:ok, :delivered} = PatientAccess.request_magic_link("academic@example.test")
    assert_email_sent()
    assert {:ok, :delivered} = PatientAccess.request_magic_link("unknown@example.test")
  end
end

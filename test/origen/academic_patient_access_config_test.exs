defmodule Origen.AcademicPatientAccessConfigTest do
  use ExUnit.Case, async: false
  alias Origen.PatientAccess
  @development_build Application.compile_env(:origen, :env) == :dev

  setup do
    previous = Application.get_env(:origen, :academic_patient_access)
    on_exit(fn -> Application.put_env(:origen, :academic_patient_access, previous) end)
  end

  test "local override only permits loopback in a development build" do
    for origin <- ["http://localhost:4000", "http://127.0.0.1:4000"] do
      Application.put_env(:origen, :academic_patient_access,
        enabled: true,
        isolated_fictional_data_confirmed: true,
        local_development: true,
        public_origin: origin
      )

      assert PatientAccess.academic_display_enabled?() ==
               @development_build
    end
  end

  test "local override never allows remote HTTP or bypasses the fictional data gate" do
    for {origin, confirmed} <- [
          {"http://evaluation.example.test", true},
          {"http://localhost:4000", false}
        ] do
      Application.put_env(:origen, :academic_patient_access,
        enabled: true,
        isolated_fictional_data_confirmed: confirmed,
        local_development: true,
        public_origin: origin
      )

      refute PatientAccess.academic_display_enabled?()
    end
  end

  test "public HTTPS evaluation remains available without the local override" do
    Application.put_env(:origen, :academic_patient_access,
      enabled: true,
      isolated_fictional_data_confirmed: true,
      public_origin: "https://evaluation.example.test"
    )

    assert PatientAccess.academic_display_enabled?()
  end

  test "loopback and malformed origins fail closed without raising" do
    for origin <- [
          "https://localhost.",
          "https://127.0.0.2",
          "https://127.1",
          "https://evaluation.example.test:notaport"
        ] do
      Application.put_env(:origen, :academic_patient_access,
        enabled: true,
        isolated_fictional_data_confirmed: true,
        public_origin: origin
      )

      refute PatientAccess.academic_display_enabled?()

      assert {:error, :disabled} =
               PatientAccess.request_academic_magic_link("patient@example.test")
    end
  end
end

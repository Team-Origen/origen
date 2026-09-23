defmodule Origen.Integration.DemoRunbookVerificationTest do
  @moduledoc """
  Suite automatizada de verificación de integridad y consistencia del Runbook de la Demo Integrada
  (Subissue #72 / PLN-14 / Father Issue #47).

  Asegura que el artefacto durable `docs/demo/RUNBOOK_DEMO_INTEGRADA.md` y todos los componentes,
  rutas, scripts y controles descritos en él son coherentes y ejecutables por el equipo y los docentes.
  """

  use ExUnit.Case, async: true

  @runbook_path Path.expand("../../../docs/demo/RUNBOOK_DEMO_INTEGRADA.md", __DIR__)
  @journey_script_path Path.expand("../../../priv/repo/check_prototype_journey_e2e.exs", __DIR__)
  @regression_script_path Path.expand(
                            "../../../priv/repo/check_journey_failure_regression.exs",
                            __DIR__
                          )

  describe "Verificación de artefacto durable (Issue #72)" do
    test "el archivo de runbook existe y es legible en la ruta canónica" do
      assert File.exists?(@runbook_path),
             "El runbook no existe en docs/demo/RUNBOOK_DEMO_INTEGRADA.md"

      content = File.read!(@runbook_path)
      assert byte_size(content) > 1000
    end

    test "los scripts ejecutables referenciados en el runbook existen y son válidos" do
      assert File.exists?(@journey_script_path),
             "El script priv/repo/check_prototype_journey_e2e.exs no existe"

      assert File.exists?(@regression_script_path),
             "El script priv/repo/check_journey_failure_regression.exs no existe"
    end

    test "documenta el procedimiento de inicialización para entorno local limpio" do
      content = File.read!(@runbook_path)

      assert content =~ "mix deps.get"
      assert content =~ "mix ecto.reset"
      assert content =~ "mix phx.server"
      assert content =~ "http://localhost:4000"
      assert content =~ "http://localhost:4000/dev/mailbox"
    end

    test "registra comandos y estados resultantes del recorrido principal (#70) y regresión (#71)" do
      content = File.read!(@runbook_path)

      assert content =~ "priv/repo/check_prototype_journey_e2e.exs"
      assert content =~ "priv/repo/check_journey_failure_regression.exs"
      assert content =~ "test/origen/integration/"
      assert content =~ "reserved"
      assert content =~ ":slot_already_booked"
      assert content =~ ":patient_not_ready_for_booking"
    end

    test "incluye controles negativos de solapamiento, perfil incompleto y accesos no autorizados" do
      content = File.read!(@runbook_path)

      # Solapamiento / concurrencia
      assert content =~ "CN-01"
      assert content =~ "Doble reserva simultánea"
      assert content =~ "GiST"

      # Teléfono no verificado
      assert content =~ "CN-02"
      assert content =~ "sin teléfono verificado"

      # Perfil incompleto
      assert content =~ "CN-03"
      assert content =~ "Perfil incompleto"

      # Colisión documental
      assert content =~ "CN-04"
      assert content =~ "Colisión documental de DNI"

      # Aislamiento horizontal e IDOR
      assert content =~ "CN-05"
      assert content =~ "Aislamiento horizontal"
      assert content =~ "CN-06"
      assert content =~ "IDOR"

      # Acceso no autorizado y sesión revocada
      assert content =~ "CN-07"
      assert content =~ "401"
      assert content =~ "403"

      # Rollback transaccional atómico
      assert content =~ "CN-08"
      assert content =~ "Rollback total"
    end

    test "garantiza trazabilidad formal con el Sprint 1 (PLN-14, #47, #70, #71, #72)" do
      content = File.read!(@runbook_path)

      assert content =~ "#47"
      assert content =~ "PLN-14"
      assert content =~ "#70"
      assert content =~ "#71"
      assert content =~ "#72"
      assert content =~ "docentes evaluadores"
    end

    test "las rutas web mencionadas en el guion de presentación existen en la aplicación" do
      routes = OrigenWeb.Router.__routes__()
      paths = Enum.map(routes, & &1.path)

      assert "/access" in paths
      assert "/patient/profile/complete" in paths
      assert "/patient/phone/verify" in paths
      assert "/patient/calendar" in paths
      assert "/profesional/agenda" in paths
    end
  end
end

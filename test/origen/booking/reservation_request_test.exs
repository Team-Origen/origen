defmodule Origen.Booking.ReservationRequestTest do
  use ExUnit.Case, async: true

  alias Origen.Booking.ReservationRequest
  alias Origen.Booking.ReservationResponse

  @valid_uuid "d4f3b8b6-96a8-4c6e-b35e-6b9f2b8a0001"
  @valid_iso_time "2026-10-15T09:00:00Z"

  @valid_params %{
    "actor" => %{
      "role" => "patient",
      "id" => 42
    },
    "patient_id" => 42,
    "professional_id" => 10,
    "consultation_type_id" => @valid_uuid,
    "start_time" => @valid_iso_time,
    "patient_agreed_schedule" => false
  }

  describe "cast_and_validate/1 con datos válidos" do
    test "acepta parámetros válidos con claves string" do
      assert {:ok, %ReservationRequest{} = req} =
               ReservationRequest.cast_and_validate(@valid_params)

      assert req.actor.role == :patient
      assert req.actor.id == 42
      assert req.patient_id == 42
      assert req.professional_id == 10
      assert req.consultation_type_id == @valid_uuid
      assert req.start_time == ~U[2026-10-15 09:00:00Z]
      assert req.patient_agreed_schedule == false
    end

    test "acepta parámetros válidos con claves atom" do
      atom_params = %{
        actor: %{role: :secretary, id: 5},
        patient_id: 42,
        professional_id: 10,
        consultation_type_id: @valid_uuid,
        start_time: ~U[2026-10-15 09:00:00Z],
        patient_agreed_schedule: true
      }

      assert {:ok, %ReservationRequest{} = req} =
               ReservationRequest.cast_and_validate(atom_params)

      assert req.actor.role == :secretary
      assert req.actor.id == 5
      assert req.patient_agreed_schedule == true
    end

    test "acepta rol professional" do
      params = put_in(@valid_params, ["actor", "role"], "professional")
      assert {:ok, %ReservationRequest{} = req} = ReservationRequest.cast_and_validate(params)
      assert req.actor.role == :professional
    end
  end

  describe "cast_and_validate/1 rechazo de estructuras mal formadas" do
    test "rechaza cuando falta patient_id" do
      params = Map.delete(@valid_params, "patient_id")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :patient_id in Keyword.keys(errors)
    end

    test "rechaza cuando falta professional_id" do
      params = Map.delete(@valid_params, "professional_id")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :professional_id in Keyword.keys(errors)
    end

    test "rechaza cuando falta consultation_type_id" do
      params = Map.delete(@valid_params, "consultation_type_id")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :consultation_type_id in Keyword.keys(errors)
    end

    test "rechaza formato inválido de consultation_type_id (no es UUID)" do
      params = Map.put(@valid_params, "consultation_type_id", "invalid-uuid-format")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :consultation_type_id in Keyword.keys(errors)
    end

    test "rechaza cuando falta start_time" do
      params = Map.delete(@valid_params, "start_time")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :start_time in Keyword.keys(errors)
    end

    test "rechaza start_time con formato no ISO8601 o texto arbitrario" do
      params = Map.put(@valid_params, "start_time", "manana_a_las_diez")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :start_time in Keyword.keys(errors)
    end

    test "rechaza cuando falta actor" do
      params = Map.delete(@valid_params, "actor")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :actor in Keyword.keys(errors)
    end

    test "rechaza actor con rol no reconocido" do
      params = put_in(@valid_params, ["actor", "role"], "superuser")
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :actor in Keyword.keys(errors)
    end

    test "rechaza actor sin id" do
      params = put_in(@valid_params, ["actor"], %{"role" => "patient"})
      assert {:error, {:malformed_request, errors}} = ReservationRequest.cast_and_validate(params)
      assert :actor in Keyword.keys(errors)
    end

    test "rechaza payloads que no son mapas" do
      assert {:error, {:malformed_request, errors}} =
               ReservationRequest.cast_and_validate("payload_invalido")

      assert is_list(errors)
    end

    test "es una validación sintáctica pura sin efectos de base de datos" do
      # Rechaza en memoria sin requerir conexión a base de datos
      assert {:error, {:malformed_request, _}} = ReservationRequest.cast_and_validate(%{})
    end
  end

  describe "ReservationResponse struct de salida" do
    test "construye contrato de salida con snapshots históricos" do
      response = %ReservationResponse{
        appointment_id: 101,
        patient_id: 42,
        professional_id: 10,
        consultation_type_id: @valid_uuid,
        start_time: ~U[2026-10-15 09:00:00Z],
        end_time: ~U[2026-10-15 09:30:00Z],
        status: :reserved,
        consultation_type_name: "Consulta General",
        duration_minutes: 30,
        base_price_amount: Decimal.new("15000.00"),
        relationship_created?: true
      }

      assert response.appointment_id == 101
      assert response.status == :reserved
      assert response.consultation_type_name == "Consulta General"
      assert response.duration_minutes == 30
      assert response.base_price_amount == Decimal.new("15000.00")
      assert response.relationship_created? == true
    end
  end
end

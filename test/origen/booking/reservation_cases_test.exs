defmodule Origen.Booking.ReservationCasesTest do
  @moduledoc """
  Esqueleto de los casos de reserva descritos en `docs/booking/RESERVATION_CASES.md`
  (subissue #61 de #41 / PLN-08).

  Cada test queda `skip` porque el motor compartido de reserva todavía no existe:
  #41 depende de PLN-05 (#38), PLN-06 (#39), PLN-07 (#40) y PLN-15 (#48), ninguna
  mergeada a `develop`. Se completan cuando #62 (datos) y #63 (guardar el turno)
  aterricen; hasta entonces documentan el comportamiento esperado.
  """

  use ExUnit.Case, async: true

  @skip_reason "Bloqueado por PLN-05/06/07/15 (#38, #39, #40, #48): el motor de reserva no existe todavía"

  @moduletag skip: @skip_reason

  describe "casos válidos" do
    test "V1: paciente autogestionado antes de D-1 con aprobación automática nace Reservado y crea la relación" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V2: paciente autogestionado antes de D-1 con aprobación manual nace Solicitado sin crear relación" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V3: paciente autogestionado durante D-1 nace Confirmado directo" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V4: secretaria asiste a paciente con perfil incompleto antes de D-1 y elige Reservado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V5: secretaria crea Confirmado explícito por horario ya acordado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V6: secretaria durante D-1 solo puede crear Confirmado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V7: profesional crea turno posterior antes de D-1 para paciente de su lista permitida, nace Reservado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V8: profesional crea turno posterior durante D-1 para paciente de su lista permitida, nace Confirmado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "V9: aprobar una solicitud Solicitado crea la relación recién al persistir el primer turno válido" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63, #64)")
    end
  end

  describe "casos rechazados" do
    test "R1: paciente con perfil incompleto no puede autogestionar su primera reserva" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #64)")
    end

    test "R2: paciente con teléfono no verificado no puede autogestionar su primera reserva" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #64)")
    end

    test "R3: dos solicitudes simultáneas por el mismo horario, solo una persiste" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#65, #66)")
    end

    test "R4: profesional no puede crear turnos para pacientes fuera de su lista permitida" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#64)")
    end

    test "R5: profesional no puede listar ni buscar el registro global de pacientes" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#64)")
    end

    test "R6: tipo de consulta inactivo o de otro profesional es rechazado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end

    test "R7: horario sin intervalos de agenda contiguos suficientes es rechazado" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#65)")
    end

    test "R8: rechazo manual de una solicitud Solicitado pasa a Cancelado con motivo obligatorio, sin multa" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#63, #64)")
    end

    test "R9: reserva pública autónoma después del corte de las 23:59 de D-1 es rechazada" do
      flunk("pendiente: implementar contra la operación de reserva cuando exista (#62, #63)")
    end
  end
end

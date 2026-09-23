defmodule Origen.Booking.ReservationResponse do
  @moduledoc """
  Contrato de datos de salida para la operación de reserva (Issue #62 / PLN-08).

  Define la forma estructurada que retorna una reserva completada exitosamente,
  incluyendo los datos de identidad, fechas calculadas, estado del turno,
  los snapshots históricos inmutables de la consulta y el indicador de creación de relación.
  """

  @type status :: :requested | :reserved | :confirmed

  @type t :: %__MODULE__{
          appointment_id: pos_integer(),
          patient_id: pos_integer(),
          professional_id: pos_integer(),
          consultation_type_id: Ecto.UUID.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t(),
          status: status(),
          consultation_type_name: String.t(),
          duration_minutes: pos_integer(),
          base_price_amount: Decimal.t(),
          relationship_created?: boolean()
        }

  defstruct [
    :appointment_id,
    :patient_id,
    :professional_id,
    :consultation_type_id,
    :start_time,
    :end_time,
    :status,
    :consultation_type_name,
    :duration_minutes,
    :base_price_amount,
    relationship_created?: false
  ]
end

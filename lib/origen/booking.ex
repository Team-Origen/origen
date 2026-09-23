defmodule Origen.Booking do
  @moduledoc """
  Contexto de dominio para la gestión y operación de reservas de turnos (PLN-08).
  """

  alias Origen.Booking.ReservationRequest

  @doc """
  Parsea y valida la estructura sintáctica de una solicitud de reserva conforme al contrato de entrada.

  Retorna `{:ok, %ReservationRequest{}}` si los datos estructurales son válidos.
  Retorna `{:error, {:malformed_request, errors}}` si la estructura es inválida.
  """
  @spec validate_request(term()) ::
          {:ok, ReservationRequest.t()} | {:error, {:malformed_request, keyword()}}
  def validate_request(attrs) do
    ReservationRequest.cast_and_validate(attrs)
  end
end

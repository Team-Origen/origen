defmodule Origen.Booking.ProfessionalBooking do
  @moduledoc """
  Orquestación de reservas creadas por el Profesional desde su propia agenda.

  La cuenta propietaria se deriva de una sesión interna revalidada y nunca de
  parámetros del cliente. La selección puede ser un paciente previamente
  relacionado o un paciente registrado cuyo DNI exacto acompañe la
  confirmación. El turno siempre nace confirmado y reutiliza el motor
  transaccional compartido de reservas.
  """

  alias Origen.Booking
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @doc """
  Confirma un turno en la agenda del Profesional autenticado.

  `params` recibe `patient_id`, `consultation_type_id`, `start_time` y,
  únicamente para un paciente todavía no relacionado, `patient_document_number`
  con el DNI exacto usado en la selección. Cualquier identificador profesional
  enviado por el cliente se ignora.
  """
  @spec reserve(map() | InternalSession.t(), map(), keyword()) ::
          {:ok, Origen.Booking.ReservationResponse.t()} | {:error, term()}
  def reserve(principal, params, opts \\ [])

  def reserve(principal, params, opts) when is_map(params) and is_list(opts) do
    with {:ok, professional_id} <- resolve_professional(principal) do
      request = %{
        actor: %{role: :professional, id: professional_id},
        patient_id: param(params, :patient_id),
        professional_id: professional_id,
        consultation_type_id: param(params, :consultation_type_id),
        start_time: param(params, :start_time),
        patient_document_number: param(params, :patient_document_number)
      }

      Booking.reserve_appointment(request, Keyword.put(opts, :initial_status, :confirmed))
    end
  end

  def reserve(_principal, _params, _opts), do: {:error, :unauthorized}

  defp resolve_professional(%InternalSession{id: session_id, account_id: account_id}),
    do: resolve_professional(%{session_id: session_id, account_id: account_id})

  defp resolve_professional(%{session_id: session_id, account_id: account_id})
       when is_integer(session_id) and is_integer(account_id) do
    case Sessions.revalidate_principal(session_id, account_id) do
      {:ok, %{account_id: professional_id, role: :professional}} ->
        {:ok, professional_id}

      _denied ->
        {:error, :unauthorized}
    end
  end

  defp resolve_professional(_principal), do: {:error, :unauthorized}

  defp param(params, key), do: Map.get(params, key, Map.get(params, Atom.to_string(key)))
end

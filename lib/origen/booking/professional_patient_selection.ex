defmodule Origen.Booking.ProfessionalPatientSelection do
  @moduledoc """
  Selector privado de pacientes para crear turnos desde la agenda del Profesional.

  La identidad del Profesional se deriva exclusivamente de una sesión interna
  activa. La lista incluye sólo pacientes con una relación previa con ese
  Profesional; la búsqueda por DNI exacto puede encontrar cualquier paciente
  registrado, pero ambas operaciones devuelven únicamente identificador,
  nombre, apellido y DNI. Ninguna operación crea turnos ni relaciones.
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @type patient_projection :: %{
          id: integer(),
          first_name: String.t(),
          last_name: String.t(),
          document_number: String.t()
        }

  @doc """
  Lista los pacientes relacionados con el Profesional de la sesión vigente.
  """
  @spec list_related(map() | InternalSession.t()) ::
          {:ok, [patient_projection()]} | {:error, :unauthorized}
  def list_related(principal) do
    with {:ok, professional_id} <- resolve_professional(principal) do
      query =
        from(r in ProfessionalPatientRelationship,
          join: profile in PatientProfile,
          on: profile.id == r.patient_profile_id,
          join: persona in Persona,
          on: persona.id == profile.persona_id,
          where: r.professional_account_id == ^professional_id,
          where: profile.state == "completed",
          order_by: [asc: persona.last_name, asc: persona.first_name, asc: profile.id],
          select: %{
            id: profile.id,
            first_name: persona.first_name,
            last_name: persona.last_name,
            document_number: persona.document_number
          }
        )

      {:ok, Repo.all(query)}
    end
  end

  @doc """
  Busca un paciente registrado por DNI exacto normalizado dentro del recorrido
  de creación de turno del Profesional.

  No acepta prefijos ni entradas no numéricas. Retorna `{:ok, nil}` cuando no
  existe un perfil de paciente completado para el DNI.
  """
  @spec find_by_exact_dni(map() | InternalSession.t(), term()) ::
          {:ok, patient_projection() | nil} | {:error, :unauthorized | :invalid_dni}
  def find_by_exact_dni(principal, document_number) do
    with {:ok, _professional_id} <- resolve_professional(principal),
         {:ok, normalized_dni} <- normalize_exact_dni(document_number) do
      query =
        from(profile in PatientProfile,
          join: persona in Persona,
          on: persona.id == profile.persona_id,
          where: profile.state == "completed",
          where: persona.document_type == "dni",
          where: persona.document_number == ^normalized_dni,
          order_by: [asc: profile.id],
          limit: 1,
          select: %{
            id: profile.id,
            first_name: persona.first_name,
            last_name: persona.last_name,
            document_number: persona.document_number
          }
        )

      {:ok, Repo.one(query)}
    end
  end

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

  defp normalize_exact_dni(document_number) when is_binary(document_number) do
    normalized = Persona.normalize_number(document_number)

    if Regex.match?(~r/^\d{7,8}$/, normalized) do
      {:ok, normalized}
    else
      {:error, :invalid_dni}
    end
  end

  defp normalize_exact_dni(_document_number), do: {:error, :invalid_dni}
end

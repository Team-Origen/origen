defmodule Origen.Booking.Authorization do
  @moduledoc """
  Reglas de autorización por actor para la operación de reserva (Issue #64 / PLN-08).

  Evalúa elegibilidad y permisos de los tres actores del motor de reservas conforme
  a `docs/booking/RESERVATION_CASES.md` §2.1:

  - **Paciente autónomo**: identidad propia (`actor.id == patient_id`), perfil en
    estado `completed` (R01) y teléfono verificado (R02). Puede reservar con cualquier
    profesional activo; la relación Profesional-Paciente se establece al reservar (RF-05).
  - **Secretaría asistida**: cuenta interna activa con rol `secretary`. Puede operar
    perfiles incompletos o completos (RF-02); el requisito histórico de declaración de
    horario acordado con el paciente (`patient_agreed_schedule`) fue retirado (#309 / #310).
  - **Profesional**: identidad propia (`actor.id == professional_id`), cuenta interna
    activa con rol `professional` y paciente dentro de su lista permitida (RF-05).

  La lista permitida del profesional (RF-05) se resuelve primero contra la tabla
  durable `professional_patient_relationships` (Issue #66) y, como fallback de
  compatibilidad, contra turnos previos válidos en estados que establecen
  relación (`reserved`, `confirmed`, `attended`, `no_show`). Se excluyen
  `requested` (nunca crea relación, §2.4) y `cancelled` (reserva deshecha).
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Booking.ReservationRequest
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo

  @actor_roles [:patient, :secretary, :professional]

  @relationship_establishing_statuses ~w(reserved confirmed attended no_show)

  @type actor :: %{role: :patient | :secretary | :professional, id: integer()}

  @type internal_account :: %{
          id: integer(),
          email: String.t() | nil,
          role: String.t(),
          state: String.t()
        }

  @type authorization :: %{
          actor: actor(),
          patient_profile: PatientProfile.t(),
          professional_account: internal_account()
        }

  @doc """
  Autoriza una solicitud de reserva según el rol del actor solicitante.

  Acepta un `%ReservationRequest{}` validado o un mapa de parámetros con la forma
  `%{actor: %{role: ..., id: ...}, patient_id: ..., professional_id: ...}` y el
  booleano opcional `patient_agreed_schedule`.

  Retorna `{:ok, %{actor: actor, patient_profile: profile, professional_account: account}}`
  cuando el actor está habilitado, o `{:error, reason}` con denegación por defecto.
  """
  @spec authorize_reservation(ReservationRequest.t() | map()) ::
          {:ok, authorization()} | {:error, atom()}
  def authorize_reservation(%ReservationRequest{actor: actor} = request)
      when not is_nil(actor) do
    authorize(
      %{role: actor.role, id: actor.id},
      request.patient_id,
      request.professional_id,
      request.patient_agreed_schedule == true,
      request.patient_document_number
    )
  end

  def authorize_reservation(%{} = params) do
    with {:ok, actor} <- normalize_actor(params[:actor] || params["actor"]),
         {:ok, patient_id} <- fetch_positive_integer(params, :patient_id),
         {:ok, professional_id} <- fetch_positive_integer(params, :professional_id) do
      agreed? = params[:patient_agreed_schedule] || params["patient_agreed_schedule"]

      document_number =
        params[:patient_document_number] || params["patient_document_number"]

      authorize(actor, patient_id, professional_id, agreed? == true, document_number)
    end
  end

  def authorize_reservation(_invalid_payload), do: {:error, :unauthorized}

  defp authorize(
         %{role: :patient, id: actor_id} = actor,
         patient_id,
         professional_id,
         _agreed?,
         _document_number
       ) do
    with :ok <- ensure_patient_identity(actor_id, patient_id),
         {:ok, profile} <- fetch_patient_profile(patient_id),
         :ok <- ensure_completed_profile(profile),
         :ok <- ensure_verified_phone(profile),
         {:ok, professional} <- fetch_professional_account(professional_id) do
      {:ok, %{actor: actor, patient_profile: profile, professional_account: professional}}
    end
  end

  defp authorize(
         %{role: :secretary, id: actor_id} = actor,
         patient_id,
         professional_id,
         agreed?,
         _document_number
       ) do
    with {:ok, _secretary} <-
           fetch_internal_account(actor_id, "secretary", :invalid_secretary_account),
         {:ok, profile} <- fetch_patient_profile(patient_id),
         :ok <- ensure_schedule_agreement(agreed?),
         {:ok, professional} <- fetch_professional_account(professional_id) do
      {:ok, %{actor: actor, patient_profile: profile, professional_account: professional}}
    end
  end

  defp authorize(
         %{role: :professional, id: actor_id} = actor,
         patient_id,
         professional_id,
         _agreed?,
         document_number
       ) do
    with :ok <- ensure_professional_identity(actor_id, professional_id),
         {:ok, professional} <- fetch_professional_account(professional_id),
         {:ok, profile} <- fetch_patient_profile(patient_id),
         :ok <- ensure_completed_profile(profile),
         :ok <- ensure_patient_permitted(patient_id, professional_id, document_number) do
      {:ok, %{actor: actor, patient_profile: profile, professional_account: professional}}
    end
  end

  defp authorize(_unknown_actor, _patient_id, _professional_id, _agreed?, _document_number),
    do: {:error, :unauthorized}

  # Identidad y reglas por actor

  defp ensure_patient_identity(actor_id, patient_id) when actor_id == patient_id, do: :ok

  defp ensure_patient_identity(_actor_id, _patient_id),
    do: {:error, :forbidden_patient_identity}

  defp ensure_professional_identity(actor_id, professional_id)
       when actor_id == professional_id,
       do: :ok

  defp ensure_professional_identity(_actor_id, _professional_id),
    do: {:error, :forbidden_professional_identity}

  defp ensure_completed_profile(%PatientProfile{state: "completed"}), do: :ok

  defp ensure_completed_profile(_incomplete_profile), do: {:error, :perfil_incompleto}

  defp ensure_verified_phone(%PatientProfile{phone_verified: true}), do: :ok

  defp ensure_verified_phone(_profile), do: {:error, :telefono_no_verificado}

  # Beta requirement (#309 / #310): retiro de exigencia histórica de acuerdo de horario para secretaría asistida.
  defp ensure_schedule_agreement(_agreement), do: :ok

  defp ensure_patient_permitted(patient_id, professional_id, document_number) do
    if permitted_by_relationship_table?(patient_id, professional_id) or
         permitted_by_prior_appointments?(patient_id, professional_id) or
         permitted_by_exact_dni?(patient_id, document_number) do
      :ok
    else
      {:error, :paciente_no_permitido}
    end
  end

  defp permitted_by_exact_dni?(_patient_id, document_number)
       when not is_binary(document_number),
       do: false

  defp permitted_by_exact_dni?(patient_id, document_number) do
    normalized = Persona.normalize_number(document_number)

    if Regex.match?(~r/^\d{7,8}$/, normalized) do
      query =
        from(profile in PatientProfile,
          join: persona in Persona,
          on: persona.id == profile.persona_id,
          where: profile.id == ^patient_id,
          where: profile.state == "completed",
          where: persona.document_type == "dni",
          where: persona.document_number == ^normalized,
          select: 1,
          limit: 1
        )

      Repo.one(query) == 1
    else
      false
    end
  end

  # La tabla durable (#66) arbitra primero la lista permitida (RF-05).
  defp permitted_by_relationship_table?(patient_id, professional_id) do
    query =
      from(r in ProfessionalPatientRelationship,
        where: r.patient_profile_id == ^patient_id,
        where: r.professional_account_id == ^professional_id,
        select: 1,
        limit: 1
      )

    Repo.one(query) == 1
  end

  # Fallback de compatibilidad: turnos previos válidos que establecen relación.
  defp permitted_by_prior_appointments?(patient_id, professional_id) do
    query =
      from(a in Appointment,
        where: a.patient_profile_id == ^patient_id,
        where: a.professional_account_id == ^professional_id,
        where: a.status in ^@relationship_establishing_statuses,
        select: 1,
        limit: 1
      )

    Repo.one(query) == 1
  end

  # Acceso a persistencia

  defp fetch_patient_profile(patient_id) do
    case Repo.get(PatientProfile, patient_id) do
      %PatientProfile{} = profile -> {:ok, profile}
      nil -> {:error, :patient_profile_not_found}
    end
  end

  defp fetch_professional_account(account_id),
    do: fetch_internal_account(account_id, "professional", :invalid_professional_account)

  defp fetch_internal_account(account_id, expected_role, error_reason) do
    case Repo.query("SELECT id, email, role, state FROM internal_accounts WHERE id = $1", [
           account_id
         ]) do
      {:ok, %{rows: [[id, email, role, state]]}}
      when role == expected_role and state == "active" ->
        {:ok, %{id: id, email: email, role: role, state: state}}

      _invalid_or_missing_account ->
        {:error, error_reason}
    end
  end

  # Normalización del contrato de entrada

  defp normalize_actor(%{role: role, id: id}) when role in @actor_roles and is_integer(id),
    do: {:ok, %{role: role, id: id}}

  defp normalize_actor(%{"role" => role, "id" => id}) when is_integer(id),
    do: normalize_actor(%{role: role, id: id})

  defp normalize_actor(%{role: role, id: id}) when is_binary(role) and is_integer(id) do
    case Enum.find(@actor_roles, &(Atom.to_string(&1) == role)) do
      nil -> {:error, :unauthorized}
      normalized_role -> {:ok, %{role: normalized_role, id: id}}
    end
  end

  defp normalize_actor(_invalid_actor), do: {:error, :unauthorized}

  defp fetch_positive_integer(params, key) do
    case params[key] || params["#{key}"] do
      id when is_integer(id) and id > 0 -> {:ok, id}
      _invalid_id -> {:error, :unauthorized}
    end
  end
end

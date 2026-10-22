defmodule Origen.Booking.RequestResolution do
  @moduledoc """
  Resolución de solicitudes de turno con aprobación manual por el Profesional dueño (Issue #284 / #322).

  Reglas del contrato #321:
  - Sólo el profesional dueño de la agenda puede aceptar o rechazar solicitudes de su agenda.
  - Aceptar: pasa de `requested` a `confirmed`. El slot sigue ocupado.
  - Rechazar: pasa de `requested` a `cancelled`. El slot queda libre inmediatamente.
  - Estados distintos a `requested` son rechazados como transición inválida.
  - Actores no profesionales o profesionales ajenos son rechazados con `{:error, :unauthorized}`.
  - Cambiar modalidad de aprobación afecta sólo a nuevas reservas, preservando pendientes existentes.
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias Origen.Booking.Appointment
  alias Origen.Repo

  @resolution_audit_insert """
  INSERT INTO public.audit_events
    (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
  VALUES ($1, $2, $3, $4, $5, $6)
  """

  @doc """
  Acepta una solicitud de turno pendiente. Exclusivo del profesional dueño.

  La validación del actor precede a cualquier consulta del turno: un actor no
  profesional o inactivo siempre recibe `{:error, :unauthorized}`, incluso ante
  IDs inexistentes, sin revelar la existencia de turnos ajenos (oráculo IDOR).
  """
  @spec accept_request(integer(), integer()) ::
          {:ok, Appointment.t()} | {:error, term()}
  def accept_request(actor_account_id, appointment_id)
      when is_integer(actor_account_id) and is_integer(appointment_id) do
    with :ok <- ensure_active_professional(actor_account_id) do
      resolve_request(actor_account_id, appointment_id, "confirmed", "appointment_confirmed")
    end
  end

  def accept_request(_invalid_actor, _invalid_appt), do: {:error, :unauthorized}

  @doc """
  Rechaza una solicitud de turno pendiente, liberando el slot. Exclusivo del profesional dueño.

  La validación del actor precede a cualquier consulta del turno (ver `accept_request/2`).
  """
  @spec reject_request(integer(), integer()) ::
          {:ok, Appointment.t()} | {:error, term()}
  def reject_request(actor_account_id, appointment_id)
      when is_integer(actor_account_id) and is_integer(appointment_id) do
    with :ok <- ensure_active_professional(actor_account_id) do
      resolve_request(actor_account_id, appointment_id, "cancelled", "appointment_cancelled")
    end
  end

  def reject_request(_invalid_actor, _invalid_appt), do: {:error, :unauthorized}

  @doc """
  Consulta la configuración de aprobación de un profesional.
  """
  @spec get_approval_configuration(integer() | String.t()) ::
          {:ok,
           %{
             approval_mode: :automatic | :manual,
             secretary_approval_mode: :confirmed | :requested
           }}
          | {:error, term()}
  def get_approval_configuration(professional_id) do
    with {:ok, owner_id} <- parse_id(professional_id) do
      query = """
      SELECT approval_mode, secretary_approval_mode FROM public.agenda_settings
      WHERE owner_account_id = $1
      """

      case SQL.query(Repo, query, [owner_id]) do
        {:ok, %{rows: [[app_mode, sec_mode]]}} ->
          {:ok,
           %{
             approval_mode: String.to_existing_atom(app_mode || "automatic"),
             secretary_approval_mode: String.to_existing_atom(sec_mode || "confirmed")
           }}

        {:ok, %{rows: []}} ->
          {:ok, %{approval_mode: :automatic, secretary_approval_mode: :confirmed}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Actualiza la modalidad de aprobación y la subconfiguración de secretaría.
  Afecta únicamente a reservas nuevas.

  Actualización parcial (Contrato #321 §3): una clave omitida (atómica o string)
  preserva su valor existente en `agenda_settings`; sólo una clave provista con
  valor inválido produce `{:error, :invalid_approval_mode}` o
  `{:error, :invalid_secretary_approval_mode}`.
  """
  @spec update_approval_configuration(integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def update_approval_configuration(professional_account_id, attrs)
      when is_integer(professional_account_id) and is_map(attrs) do
    with :ok <- ensure_active_professional(professional_account_id),
         {:ok, app_mode} <- validate_optional_approval_mode(attrs),
         {:ok, sec_mode} <- validate_optional_secretary_mode(attrs) do
      query = """
      UPDATE public.agenda_settings
      SET approval_mode = COALESCE($1, approval_mode),
          secretary_approval_mode = COALESCE($2, secretary_approval_mode),
          updated_at = clock_timestamp()
      WHERE owner_account_id = $3
      RETURNING approval_mode, secretary_approval_mode
      """

      case SQL.query(Repo, query, [app_mode, sec_mode, professional_account_id]) do
        {:ok, %{rows: [[updated_app, updated_sec]]}} ->
          {:ok,
           %{
             approval_mode: String.to_existing_atom(updated_app),
             secretary_approval_mode: String.to_existing_atom(updated_sec)
           }}

        {:ok, %{rows: []}} ->
          {:error, :settings_not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def update_approval_configuration(_invalid_actor, _attrs), do: {:error, :unauthorized}

  # Resolución atómica (Contrato #321 §2): bloquea la fila del turno con FOR UPDATE,
  # re-verifica propiedad y estado `requested` sobre la fila bloqueada (protección
  # TOCTOU) y emite el evento de auditoría append-only minimizado en la misma
  # transacción. Ante cualquier fallo la transacción completa se revierte.

  defp resolve_request(actor_account_id, appointment_id, target_status, audit_event) do
    Repo.transaction(fn ->
      appointment = lock_appointment!(appointment_id)

      if appointment.professional_account_id != actor_account_id do
        Repo.rollback(:unauthorized)
      end

      if appointment.status != "requested" do
        Repo.rollback(:invalid_status_transition)
      end

      appointment
      |> Appointment.changeset(%{status: target_status})
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          :ok = append_resolution_audit_event!(actor_account_id, audit_event, updated)
          updated

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp lock_appointment!(appointment_id) do
    query = from(a in Appointment, where: a.id == ^appointment_id, lock: "FOR UPDATE")

    case Repo.one(query) do
      %Appointment{} = appointment -> appointment
      nil -> Repo.rollback(:appointment_not_found)
    end
  end

  # Auditoría append-only minimizada: actor, entidad y resultado; sin datos
  # clínicos ni sensibles. La inserción viaja en la misma transacción.

  defp append_resolution_audit_event!(actor_account_id, event, %Appointment{} = appointment) do
    values = [
      "professional",
      "internal_account:#{actor_account_id}",
      event,
      "appointment",
      "appointment:#{appointment.id}",
      "succeeded"
    ]

    case SQL.query(Repo, @resolution_audit_insert, values) do
      {:ok, _result} -> :ok
      {:error, _reason} -> Repo.rollback(:fallo_auditoria)
    end
  end

  # Helpers privados

  defp ensure_active_professional(actor_id) do
    query = """
    SELECT state FROM public.internal_accounts
    WHERE id = $1 AND role = 'professional' AND state = 'active'
    """

    case SQL.query(Repo, query, [actor_id]) do
      {:ok, %{rows: [["active"]]}} -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  # Validación de actualización parcial: `nil` (clave omitida) preserva el valor
  # existente; un valor provisto inválido devuelve el error específico.

  defp validate_optional_approval_mode(attrs) do
    case Map.get(attrs, :approval_mode, Map.get(attrs, "approval_mode")) do
      nil -> {:ok, nil}
      mode when mode in [:automatic, "automatic"] -> {:ok, "automatic"}
      mode when mode in [:manual, "manual"] -> {:ok, "manual"}
      _invalid -> {:error, :invalid_approval_mode}
    end
  end

  defp validate_optional_secretary_mode(attrs) do
    case Map.get(attrs, :secretary_approval_mode, Map.get(attrs, "secretary_approval_mode")) do
      nil -> {:ok, nil}
      mode when mode in [:confirmed, "confirmed"] -> {:ok, "confirmed"}
      mode when mode in [:requested, "requested"] -> {:ok, "requested"}
      _invalid -> {:error, :invalid_secretary_approval_mode}
    end
  end

  defp parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {num, ""} when num > 0 -> {:ok, num}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}
end

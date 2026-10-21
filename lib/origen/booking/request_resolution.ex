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

  alias Ecto.Adapters.SQL
  alias Origen.Booking.Appointment
  alias Origen.Repo

  @doc """
  Acepta una solicitud de turno pendiente. Exclusivo del profesional dueño.
  """
  @spec accept_request(integer(), integer()) ::
          {:ok, Appointment.t()} | {:error, term()}
  def accept_request(actor_account_id, appointment_id)
      when is_integer(actor_account_id) and is_integer(appointment_id) do
    with {:ok, appointment} <- fetch_appointment(appointment_id),
         :ok <- ensure_professional_owner(actor_account_id, appointment.professional_account_id),
         :ok <- ensure_requested_status(appointment.status) do
      appointment
      |> Appointment.changeset(%{status: "confirmed"})
      |> Repo.update()
    end
  end

  def accept_request(_invalid_actor, _invalid_appt), do: {:error, :unauthorized}

  @doc """
  Rechaza una solicitud de turno pendiente, liberando el slot. Exclusivo del profesional dueño.
  """
  @spec reject_request(integer(), integer()) ::
          {:ok, Appointment.t()} | {:error, term()}
  def reject_request(actor_account_id, appointment_id)
      when is_integer(actor_account_id) and is_integer(appointment_id) do
    with {:ok, appointment} <- fetch_appointment(appointment_id),
         :ok <- ensure_professional_owner(actor_account_id, appointment.professional_account_id),
         :ok <- ensure_requested_status(appointment.status) do
      appointment
      |> Appointment.changeset(%{status: "cancelled"})
      |> Repo.update()
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
  """
  @spec update_approval_configuration(integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def update_approval_configuration(professional_account_id, attrs)
      when is_integer(professional_account_id) and is_map(attrs) do
    with :ok <- ensure_active_professional(professional_account_id),
         {:ok, app_mode} <-
           validate_approval_mode(attrs[:approval_mode] || attrs["approval_mode"]),
         {:ok, sec_mode} <-
           validate_secretary_mode(
             attrs[:secretary_approval_mode] || attrs["secretary_approval_mode"]
           ) do
      query = """
      UPDATE public.agenda_settings
      SET approval_mode = $1, secretary_approval_mode = $2, updated_at = clock_timestamp()
      WHERE owner_account_id = $3
      RETURNING approval_mode, secretary_approval_mode
      """

      case SQL.query(Repo, query, [
             to_string(app_mode),
             to_string(sec_mode),
             professional_account_id
           ]) do
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

  # Helpers privados

  defp fetch_appointment(appointment_id) do
    case Repo.get(Appointment, appointment_id) do
      %Appointment{} = appt -> {:ok, appt}
      nil -> {:error, :appointment_not_found}
    end
  end

  defp ensure_professional_owner(actor_id, owner_id) do
    query = """
    SELECT role, state FROM public.internal_accounts
    WHERE id = $1 AND role = 'professional' AND state = 'active'
    """

    case SQL.query(Repo, query, [actor_id]) do
      {:ok, %{rows: [["professional", "active"]]}} when actor_id == owner_id ->
        :ok

      _ ->
        {:error, :unauthorized}
    end
  end

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

  defp ensure_requested_status("requested"), do: :ok
  defp ensure_requested_status(_other), do: {:error, :invalid_status_transition}

  defp validate_approval_mode(nil), do: {:ok, :automatic}
  defp validate_approval_mode(mode) when mode in [:automatic, "automatic"], do: {:ok, :automatic}
  defp validate_approval_mode(mode) when mode in [:manual, "manual"], do: {:ok, :manual}
  defp validate_approval_mode(_), do: {:error, :invalid_approval_mode}

  defp validate_secretary_mode(nil), do: {:ok, :confirmed}
  defp validate_secretary_mode(mode) when mode in [:confirmed, "confirmed"], do: {:ok, :confirmed}
  defp validate_secretary_mode(mode) when mode in [:requested, "requested"], do: {:ok, :requested}
  defp validate_secretary_mode(_), do: {:error, :invalid_secretary_approval_mode}

  defp parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {num, ""} when num > 0 -> {:ok, num}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}
end

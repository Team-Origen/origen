defmodule Origen.Booking.Agenda do
  @moduledoc """
  Consulta de la agenda propia de turnos de un Profesional autenticado
  (Issue #79 / PLN-10).

  La identidad del Profesional se deriva exclusivamente de la sesión activa
  revalidada en el servidor (`Origen.Sessions.revalidate_principal/2`) y se
  autoriza con la regla `own_02` de `:read_own_agenda` en
  `Origen.Authorization.Rules`. Ningún parámetro del cliente puede ampliar el
  alcance de la consulta: los identificadores de identidad enviados por el
  cliente se ignoran por completo y la consulta se filtra siempre por la
  cuenta propietaria de la sesión.

  La proyección es deliberadamente operativa y no clínica: horario, estado,
  tipo de consulta con sus snapshots históricos y datos de contacto básicos
  del Paciente (nombre, documento, email y teléfono).
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.Booking.Appointment
  alias Origen.Patients.{PatientProfile, Persona}
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @doc """
  Retorna la agenda diaria de turnos propios del Profesional autenticado.

  `principal` puede ser `%{session_id: integer, account_id: integer}` o un
  `%Origen.Sessions.InternalSession{}` de la sesión en curso. `params` acepta
  opcionalmente `date` (clave atom o string) como `Date` o cadena ISO8601
  (`"2026-10-15"`); por defecto se consulta el día actual UTC.

  Retorna `{:ok, %{date: date, professional_account_id: id, appointments: list}}`
  con los turnos ordenados por `start_time` ascendente. Cada turno proyecta
  `id`, `start_time`, `end_time`, `status`, `consultation_type_name`,
  `duration_minutes`, `price_ars` y un `patient` no clínico (`id`, `name`
  resuelto como nombre completo de la persona o email del perfil,
  `first_name`, `last_name`, `email`, `phone`, `document_type`,
  `document_number`).

  Falla cerrado con `{:error, :unauthorized}` ante sesiones inexistentes,
  revocadas, expiradas, cuentas inactivas o roles distintos a `:professional`.
  Retorna `{:error, :invalid_date}` cuando `date` llega en formato ilegible.
  """
  @spec get_professional_agenda(map() | InternalSession.t(), map()) ::
          {:ok, %{date: Date.t(), professional_account_id: integer(), appointments: [map()]}}
          | {:error, :unauthorized | :invalid_date}
  def get_professional_agenda(principal, params \\ %{})

  def get_professional_agenda(%InternalSession{id: session_id, account_id: account_id}, params),
    do: get_professional_agenda(%{session_id: session_id, account_id: account_id}, params)

  def get_professional_agenda(
        %{session_id: session_id, account_id: account_id},
        params
      )
      when is_integer(session_id) and is_integer(account_id) and is_map(params) do
    with {:ok, owner_id} <- resolve_owner(session_id, account_id),
         {:ok, date} <- resolve_date(params) do
      {:ok,
       %{
         date: date,
         professional_account_id: owner_id,
         appointments: query_day_appointments(owner_id, date)
       }}
    end
  end

  def get_professional_agenda(_principal, _params), do: {:error, :unauthorized}

  # Identidad: solo la sesión revalidada en el servidor define al dueño de la
  # agenda. `owner_matches_actor` se satisface por construcción porque el
  # `owner_id` proviene de la propia cuenta de la sesión, nunca de `params`.

  defp resolve_owner(session_id, claimed_account_id) do
    with {:ok, %{account_id: owner_id, role: :professional}} <-
           Sessions.revalidate_principal(session_id, claimed_account_id),
         {:allow, :own_02} <- authorize_read_own_agenda() do
      {:ok, owner_id}
    else
      _denied -> {:error, :unauthorized}
    end
  end

  defp authorize_read_own_agenda do
    Request.new(
      operation: Fact.known(:read_own_agenda),
      subject: Fact.known({:role, :professional}),
      account_state: Fact.known(:active),
      target: Fact.known(%{owner_matches_actor: true}),
      scope: Fact.known(%{authenticated: true})
    )
    |> Authorization.decide()
  end

  # Fecha objetivo: `Date` o cadena ISO8601, por defecto hoy en UTC. Cualquier
  # valor de fecha ilegible se rechaza con un error explícito.

  defp resolve_date(params) do
    case param(params, :date) do
      nil -> {:ok, Date.utc_today()}
      %Date{} = date -> {:ok, date}
      date when is_binary(date) -> parse_date(date)
      _invalid -> {:error, :invalid_date}
    end
  end

  defp parse_date(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _reason} -> {:error, :invalid_date}
    end
  end

  defp param(params, key), do: Map.get(params, key, Map.get(params, Atom.to_string(key)))

  # Consulta del día `[day_start, day_end)` en UTC, limitada por construction al
  # `owner_id` de la sesión y ordenada cronológicamente. El join con
  # `personas` es izquierdo: el perfil puede existir sin persona asociada.

  defp query_day_appointments(owner_id, date) do
    day_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.add(day_start, 1, :day)

    query =
      from(a in Appointment,
        join: p in PatientProfile,
        on: p.id == a.patient_profile_id,
        left_join: per in Persona,
        on: per.id == p.persona_id,
        where: a.professional_account_id == ^owner_id,
        where: a.start_time >= ^day_start and a.start_time < ^day_end,
        order_by: [asc: a.start_time],
        select: %{
          id: a.id,
          start_time: a.start_time,
          end_time: a.end_time,
          status: a.status,
          consultation_type_name: a.snapshot_consultation_type_name,
          duration_minutes: a.snapshot_duration_minutes,
          price_ars: a.snapshot_exact_price_ars,
          patient: %{
            id: p.id,
            name:
              fragment(
                "COALESCE(NULLIF(TRIM(CONCAT_WS(' ', ?, ?)), ''), ?)",
                per.first_name,
                per.last_name,
                p.email
              ),
            first_name: per.first_name,
            last_name: per.last_name,
            email: p.email,
            phone: p.phone,
            document_type: per.document_type,
            document_number: per.document_number
          }
        }
      )

    Repo.all(query)
  end
end

defmodule Origen.Appointments.DatabaseCalendar do
  @moduledoc """
  Database-backed calendar adapter for persisted professional settings,
  consultation durations, and active appointment occupancy.
  """

  @behaviour Origen.Appointments.Calendar

  alias Origen.Appointments.Availability
  alias Origen.Booking.Expiry
  alias Origen.Repo

  @weekday_map %{
    1 => "monday",
    2 => "tuesday",
    3 => "wednesday",
    4 => "thursday",
    5 => "friday",
    6 => "saturday",
    7 => "sunday"
  }

  @default_policy %{
    cutoff_description: "Podés cancelar estrictamente antes del inicio de la cita.",
    penalty_percentage: 0,
    penalty_description: "No se aplica penalización automática por cancelación ni inasistencia."
  }

  @impl true
  def list_professionals do
    query = """
    SELECT a.id, p.first_name, p.last_name, p.specialty
    FROM internal_accounts a
    JOIN professional_profiles p ON p.owner_account_id = a.id
    WHERE a.role = 'professional' AND a.state = 'active'
      AND NULLIF(btrim(p.first_name, E' \\t\\n\\r'), '') IS NOT NULL
      AND NULLIF(btrim(p.last_name, E' \\t\\n\\r'), '') IS NOT NULL
      AND NULLIF(btrim(p.specialty, E' \\t\\n\\r'), '') IS NOT NULL
      AND NULLIF(btrim(p.license_type, E' \\t\\n\\r'), '') IS NOT NULL
      AND NULLIF(btrim(p.license_number, E' \\t\\n\\r'), '') IS NOT NULL
    ORDER BY a.id ASC
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        professionals =
          Enum.map(rows, fn [id, first_name, last_name, specialty] ->
            %{id: to_string(id), name: "#{first_name} #{last_name}", specialty: specialty}
          end)

        {:ok, professionals}

      _error ->
        {:error, :unavailable}
    end
  end

  @impl true
  def get_daily_schedule(professional_id, date),
    do: get_daily_schedule(professional_id, date, [])

  @impl true
  def get_daily_schedule(professional_id, %Date{} = date, opts) do
    with {:ok, owner_id} <- parse_owner_id(professional_id),
         {:ok, settings} <- fetch_agenda_settings(owner_id),
         {:ok, occupancies} <- fetch_occupancies(owner_id, date, opts),
         {:ok, identity} <- fetch_professional_identity(owner_id) do
      day_key = Map.fetch!(@weekday_map, Date.day_of_week(date))
      week = decode_week(settings.weekly_availability)

      windows =
        Enum.map(Map.get(week, day_key, []), fn %{"start" => start_time, "end" => end_time} ->
          {parse_time!(start_time), parse_time!(end_time)}
        end)

      duration = Keyword.get(opts, :duration_minutes, 30)

      slots =
        Availability.calculate_slots(
          date,
          windows,
          occupancies,
          agenda_interval_minutes: settings.interval_minutes,
          duration_minutes: duration,
          min_lead_time_minutes: settings.minimum_lead_minutes,
          booking_horizon_days: settings.booking_horizon_days,
          now: Keyword.get(opts, :now, DateTime.utc_now()),
          timezone: Keyword.get(opts, :timezone, "Etc/UTC")
        )

      {:ok,
       %{
         date: date,
         professional_id: to_string(owner_id),
         professional_name: identity.name,
         specialty: identity.specialty,
         slots: slots,
         cancellation_policy: @default_policy
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_owner_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  defp parse_owner_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> {:error, :invalid_professional}
    end
  end

  defp parse_owner_id(_), do: {:error, :invalid_professional}

  defp fetch_agenda_settings(owner_id) do
    query = """
    SELECT s.weekly_availability, s.booking_horizon_days, s.minimum_lead_minutes, s.interval_minutes
    FROM agenda_settings s
    JOIN internal_accounts a ON a.id = s.owner_account_id
    WHERE s.owner_account_id = $1 AND a.role = 'professional' AND a.state = 'active'
    """

    case Repo.query(query, [owner_id]) do
      {:ok, %{rows: [[week, horizon, lead, interval]]}} ->
        {:ok,
         %{
           weekly_availability: week,
           booking_horizon_days: horizon,
           minimum_lead_minutes: lead,
           interval_minutes: interval
         }}

      {:ok, %{rows: []}} ->
        {:error, :invalid_professional}

      _error ->
        {:error, :unavailable}
    end
  end

  defp fetch_occupancies(owner_id, date, opts) do
    with {:ok, _result} <- Expiry.expire_due_requested(now: Keyword.get(opts, :now)) do
      case Keyword.fetch(opts, :occupancies) do
        {:ok, occupancies} ->
          {:ok, occupancies}

        :error ->
          start_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          end_day = DateTime.add(start_day, 1, :day)

          query = """
          SELECT start_time, end_time
          FROM appointments
          WHERE professional_account_id = $1
            AND status NOT IN ('cancelled', 'rejected', 'expired')
            AND start_time < $2 AND end_time > $3
          ORDER BY start_time
          """

          case Repo.query(query, [owner_id, end_day, start_day]) do
            {:ok, %{rows: rows}} ->
              {:ok, Enum.map(rows, &occupancy_for_day(&1, start_day, end_day))}

            _error ->
              {:error, :unavailable}
          end
      end
    else
      {:error, reason} -> {:error, {:expiry_failed, reason}}
    end
  end

  defp occupancy_for_day([start_datetime, end_datetime], start_day, end_day) do
    start_time =
      if DateTime.compare(start_datetime, start_day) == :lt,
        do: ~T[00:00:00],
        else: DateTime.to_time(start_datetime)

    end_time =
      if DateTime.compare(end_datetime, end_day) != :lt,
        do: ~T[23:59:59.999999],
        else: DateTime.to_time(end_datetime)

    {start_time, end_time}
  end

  defp fetch_professional_identity(owner_id) do
    case Repo.query(
           """
           SELECT first_name, last_name, specialty
           FROM professional_profiles
           WHERE owner_account_id = $1
           """,
           [owner_id]
         ) do
      {:ok, %{rows: [[first_name, last_name, specialty]]}} ->
        {:ok, %{name: "#{first_name} #{last_name}", specialty: specialty}}

      {:ok, %{rows: []}} ->
        {:ok, %{name: "Profesional ##{owner_id}", specialty: "Medicina General"}}

      _error ->
        {:error, :unavailable}
    end
  end

  defp decode_week(map) when is_map(map), do: map
  defp decode_week(str) when is_binary(str), do: Jason.decode!(str)
  defp decode_week(_), do: %{}

  defp parse_time!(str) do
    formatted = if String.length(str) == 5, do: str <> ":00", else: str
    Time.from_iso8601!(formatted)
  end
end

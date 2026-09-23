defmodule Origen.Availability do
  @moduledoc """
  Own regular availability configuration for authenticated Professionals.

  Ownership and authorization are revalidated from persistence for every operation.
  """

  alias Origen.Audit.{Events, Writer}
  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.Repo
  alias Origen.Sessions

  @days ~w(monday tuesday wednesday thursday friday saturday sunday)a
  @protected_fields [:owner_account_id, :account_id, "owner_account_id", "account_id"]
  @audit_decision {:allow, :sys_01}

  @spec get_own_configuration(map()) :: {:ok, map()} | {:error, :unauthorized | :unavailable}
  def get_own_configuration(%{session_id: session_id, account_id: account_id})
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      with {:ok, owner_id} <- resolve_owner(session_id, account_id, :read_own_availability) do
        owner_id |> get_or_create_settings!() |> row_to_configuration()
      end
    end)
    |> transaction_result()
  rescue
    _error -> {:error, :unavailable}
  end

  def get_own_configuration(_principal), do: {:error, :unauthorized}

  @spec replace_own_configuration(map(), map()) ::
          {:ok, map()} | {:error, :unauthorized | :unavailable | {:validation, map()}}
  def replace_own_configuration(%{session_id: session_id, account_id: account_id}, attrs)
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      with {:ok, owner_id} <- resolve_owner(session_id, account_id, :replace_own_availability) do
        [_week, _horizon, _lead, interval] = get_or_create_settings!(owner_id)

        case validate(attrs, interval) do
          {:ok, configuration} ->
            persisted = replace_settings!(owner_id, configuration)
            append_audit!(owner_id)
            row_to_configuration(persisted)

          {:error, errors} ->
            Repo.rollback({:validation, errors})
        end
      end
    end)
    |> transaction_result()
  rescue
    _error -> {:error, :unavailable}
  end

  def replace_own_configuration(_principal, _attrs), do: {:error, :unauthorized}

  defp transaction_result({:ok, {:error, :unauthorized}}), do: {:error, :unauthorized}
  defp transaction_result({:ok, result}), do: {:ok, result}
  defp transaction_result({:error, :unauthorized}), do: {:error, :unauthorized}
  defp transaction_result({:error, {:validation, errors}}), do: {:error, {:validation, errors}}
  defp transaction_result({:error, _reason}), do: {:error, :unavailable}

  defp resolve_owner(session_id, claimed_account_id, operation) do
    with {:ok, %{account_id: owner_id, role: :professional}} <-
           Sessions.revalidate_principal(session_id, claimed_account_id),
         {:allow, :own_02} <- authorize(operation) do
      {:ok, owner_id}
    else
      _denied -> {:error, :unauthorized}
    end
  end

  defp authorize(operation) do
    Request.new(
      operation: Fact.known(operation),
      subject: Fact.known({:role, :professional}),
      account_state: Fact.known(:active),
      target: Fact.known(%{owner_matches_actor: true}),
      scope: Fact.known(%{authenticated: true})
    )
    |> Authorization.decide()
  end

  defp get_or_create_settings!(owner_id) do
    Repo.query!(
      "INSERT INTO agenda_settings (owner_account_id) VALUES ($1) ON CONFLICT DO NOTHING",
      [owner_id]
    )

    Repo.query!(
      """
      SELECT weekly_availability, booking_horizon_days, minimum_lead_minutes, interval_minutes
       FROM agenda_settings WHERE owner_account_id = $1
      """,
      [owner_id]
    ).rows
    |> List.first()
  end

  defp replace_settings!(owner_id, configuration) do
    Repo.query!(
      """
      UPDATE agenda_settings
      SET weekly_availability = $2, booking_horizon_days = $3,
          minimum_lead_minutes = $4, updated_at = clock_timestamp()
      WHERE owner_account_id = $1
      RETURNING weekly_availability, booking_horizon_days, minimum_lead_minutes, interval_minutes
      """,
      [
        owner_id,
        configuration.weekly_availability,
        configuration.booking_horizon_days,
        configuration.minimum_lead_minutes
      ]
    ).rows
    |> List.first()
  end

  defp append_audit!(owner_id) do
    reference = Integer.to_string(owner_id)

    with {:ok, event} <-
           Events.availability_configuration_replaced({:professional, reference}, reference),
         {:ok, _audit} <- Writer.append(event, @audit_decision) do
      :ok
    else
      _failure -> Repo.rollback(:audit_unavailable)
    end
  end

  defp validate(attrs, interval) when is_map(attrs) do
    if Enum.any?(@protected_fields, &Map.has_key?(attrs, &1)) do
      {:error, %{base: :protected_fields}}
    else
      validations = %{
        weekly_availability: validate_week(fetch(attrs, :weekly_availability), interval),
        booking_horizon_days: validate_horizon(fetch(attrs, :booking_horizon_days)),
        minimum_lead_minutes: validate_lead(fetch(attrs, :minimum_lead_minutes))
      }

      errors =
        Map.new(validations, fn
          {field, {:error, reason}} -> {field, reason}
          {field, {:ok, _value}} -> {field, nil}
        end)
        |> Map.reject(fn {_field, reason} -> is_nil(reason) end)

      if map_size(errors) == 0 do
        {:ok, Map.new(validations, fn {field, {:ok, value}} -> {field, value} end)}
      else
        {:error, errors}
      end
    end
  end

  defp validate(_attrs, _interval), do: {:error, %{base: :invalid}}

  defp validate_week(week, interval) when is_map(week) and map_size(week) == 7 do
    results = Map.new(@days, &{&1, validate_day(day_value(week, &1), interval)})

    errors =
      results
      |> Enum.flat_map(fn
        {day, {:error, reason}} -> [{day, reason}]
        {_day, {:ok, _windows}} -> []
      end)
      |> Map.new()

    cond do
      not exact_day_keys?(week) ->
        {:error, :invalid_days}

      map_size(errors) > 0 ->
        {:error, errors}

      true ->
        {:ok, Map.new(results, fn {day, {:ok, windows}} -> {Atom.to_string(day), windows} end)}
    end
  end

  defp validate_week(_week, _interval), do: {:error, :invalid_shape}

  defp validate_day(windows, interval) when is_list(windows) do
    with {:ok, parsed} <- parse_windows(windows, interval),
         {:ok, normalized} <- merge_windows(Enum.sort_by(parsed, & &1.start_minutes)) do
      {:ok, Enum.map(normalized, &%{"start" => &1.start, "end" => &1.end})}
    end
  end

  defp validate_day(_windows, _interval), do: {:error, :invalid_windows}

  defp parse_windows(windows, interval) do
    Enum.reduce_while(windows, {:ok, []}, fn window, {:ok, parsed} ->
      case parse_window(window, interval) do
        {:ok, value} -> {:cont, {:ok, [value | parsed]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp parse_window(window, interval) when is_map(window) and map_size(window) == 2 do
    start_text = fetch(window, :start)
    end_text = fetch(window, :end)

    with {:ok, start_minutes} <- parse_time(start_text),
         {:ok, end_minutes} <- parse_time(end_text),
         true <- end_minutes > start_minutes || {:error, :overnight_or_empty},
         true <-
           (rem(start_minutes, interval) == 0 and rem(end_minutes, interval) == 0) ||
             {:error, :misaligned},
         true <- end_minutes - start_minutes >= interval || {:error, :too_short} do
      {:ok,
       %{start: start_text, end: end_text, start_minutes: start_minutes, end_minutes: end_minutes}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_window(_window, _interval), do: {:error, :invalid_window}

  defp merge_windows(windows) do
    windows
    |> Enum.reduce_while([], fn
      window, [] ->
        {:cont, [window]}

      window, [previous | rest] ->
        cond do
          window.start_minutes < previous.end_minutes ->
            {:halt, {:error, :overlap}}

          window.start_minutes == previous.end_minutes ->
            {:cont, [%{previous | end: window.end, end_minutes: window.end_minutes} | rest]}

          true ->
            {:cont, [window, previous | rest]}
        end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      merged -> {:ok, Enum.reverse(merged)}
    end
  end

  defp parse_time(value) when is_binary(value) do
    case Regex.run(~r/^(?:[01]\d|2[0-3]):[0-5]\d$|^24:00$/, value) do
      nil ->
        {:error, :invalid_time}

      _match ->
        [hour, minute] = value |> String.split(":") |> Enum.map(&String.to_integer/1)
        {:ok, hour * 60 + minute}
    end
  end

  defp parse_time(_value), do: {:error, :invalid_time}

  defp validate_horizon(value) when is_integer(value) and value in 7..90, do: {:ok, value}
  defp validate_horizon(value) when is_integer(value), do: {:error, :out_of_range}
  defp validate_horizon(_value), do: {:error, :invalid}

  defp validate_lead(value) when is_integer(value) and value in 0..1440 do
    if rem(value, 5) == 0, do: {:ok, value}, else: {:error, :invalid_increment}
  end

  defp validate_lead(value) when is_integer(value), do: {:error, :out_of_range}
  defp validate_lead(_value), do: {:error, :invalid}

  defp exact_day_keys?(week) do
    week
    |> Map.keys()
    |> Enum.map(fn key -> if is_atom(key), do: key, else: String.to_existing_atom(key) end)
    |> Enum.sort() == Enum.sort(@days)
  rescue
    ArgumentError -> false
  end

  defp day_value(week, day), do: Map.get(week, day, Map.get(week, Atom.to_string(day)))
  defp fetch(map, field), do: Map.get(map, field, Map.get(map, Atom.to_string(field)))

  defp row_to_configuration([week, horizon, lead, interval]) do
    %{
      weekly_availability:
        Map.new(@days, fn day ->
          windows = Map.fetch!(week, Atom.to_string(day))
          {day, Enum.map(windows, &%{start: Map.fetch!(&1, "start"), end: Map.fetch!(&1, "end")})}
        end),
      booking_horizon_days: horizon,
      minimum_lead_minutes: lead,
      agenda_interval_minutes: interval,
      timezone: Application.fetch_env!(:origen, :organization_timezone)
    }
  end
end

defmodule Origen.Appointments.Availability do
  @moduledoc """
  Pure functional domain engine for calculating appointment availability (RF-11, PLN-09).
  Computes truly bookable slots by evaluating:
  - Professional shift windows (continuous interval fitting)
  - Consultation type duration (multi-interval span)
  - Collision detection against existing active occupancies
  - Booking window boundaries (lead time and future horizon)
  """

  @type time_interval :: {Time.t(), Time.t()} | %{start_time: Time.t(), end_time: Time.t()}

  @type slot :: %{
          id: String.t(),
          start_time: Time.t(),
          end_time: Time.t(),
          start_formatted: String.t(),
          end_formatted: String.t(),
          status: :available
        }

  @default_interval_minutes 30
  @default_duration_minutes 30
  @default_min_lead_minutes 30
  @default_horizon_days 30

  @doc """
  Calculates available booking slots for a given date, windows of attention, and existing occupancies.
  """
  @spec calculate_slots(Date.t(), [time_interval()], [time_interval()], keyword()) :: [slot()]
  def calculate_slots(date, windows, occupancies, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    today = DateTime.to_date(now)
    horizon_days = Keyword.get(opts, :booking_horizon_days, @default_horizon_days)

    cond do
      Date.compare(date, today) == :lt ->
        []

      Date.diff(date, today) > horizon_days ->
        []

      true ->
        interval = Keyword.get(opts, :agenda_interval_minutes, @default_interval_minutes)
        duration = Keyword.get(opts, :duration_minutes, @default_duration_minutes)
        min_lead = Keyword.get(opts, :min_lead_time_minutes, @default_min_lead_minutes)

        normalized_windows = normalize_and_merge_intervals(windows)
        normalized_occupancies = normalize_intervals(occupancies)

        normalized_windows
        |> Enum.flat_map(fn {w_start, w_end} ->
          generate_window_slots(
            date,
            w_start,
            w_end,
            interval,
            duration,
            normalized_occupancies,
            today,
            now,
            min_lead
          )
        end)
        |> Enum.sort_by(& &1.start_time, Time)
    end
  end

  defp generate_window_slots(
         date,
         w_start,
         w_end,
         interval,
         duration,
         occupancies,
         today,
         now,
         min_lead
       ) do
    step_seconds = interval * 60
    duration_seconds = duration * 60

    generate_candidates(w_start, w_end, step_seconds, duration_seconds)
    |> Enum.filter(fn {c_start, c_end} ->
      fits_in_window?(c_end, w_end) and
        not overlaps_any?(c_start, c_end, occupancies) and
        satisfies_lead_time?(date, c_start, today, now, min_lead)
    end)
    |> Enum.map(fn {c_start, c_end} ->
      build_slot(date, c_start, c_end)
    end)
  end

  defp generate_candidates(current, w_end, step_seconds, duration_seconds) do
    if Time.compare(current, w_end) == :lt do
      c_end = Time.add(current, duration_seconds, :second)

      [
        {current, c_end}
        | generate_candidates(
            Time.add(current, step_seconds, :second),
            w_end,
            step_seconds,
            duration_seconds
          )
      ]
    else
      []
    end
  end

  defp fits_in_window?(c_end, w_end) do
    Time.compare(c_end, w_end) in [:lt, :eq]
  end

  defp overlaps_any?(c_start, c_end, occupancies) do
    Enum.any?(occupancies, fn {o_start, o_end} ->
      # Two intervals [A, B] and [C, D] overlap if A < D and B > C
      Time.compare(c_start, o_end) == :lt and Time.compare(c_end, o_start) == :gt
    end)
  end

  defp satisfies_lead_time?(date, c_start, today, now, min_lead) do
    if Date.compare(date, today) == :eq do
      now_time = DateTime.to_time(now)
      earliest_allowed = Time.add(now_time, min_lead * 60, :second)
      Time.compare(c_start, earliest_allowed) in [:gt, :eq]
    else
      true
    end
  end

  defp build_slot(date, c_start, c_end) do
    start_fmt = format_time(c_start)
    end_fmt = format_time(c_end)
    date_str = Date.to_iso8601(date)
    slot_id = "SLOT-" <> date_str <> "-" <> String.replace(start_fmt, ":", "")

    %{
      id: slot_id,
      start_time: c_start,
      end_time: c_end,
      start_formatted: start_fmt,
      end_formatted: end_fmt,
      status: :available
    }
  end

  defp format_time(%Time{hour: h, minute: m}) do
    :io_lib.format("~2..0B:~2..0B", [h, m]) |> IO.iodata_to_binary()
  end

  defp normalize_intervals(intervals) do
    intervals
    |> Enum.map(&to_time_tuple/1)
    |> Enum.filter(fn
      {s, e} -> Time.compare(s, e) == :lt
      _ -> false
    end)
    |> Enum.sort_by(fn {s, _e} -> s end, Time)
  end

  defp normalize_and_merge_intervals(intervals) do
    intervals
    |> normalize_intervals()
    |> merge_adjacent()
  end

  defp merge_adjacent([]), do: []
  defp merge_adjacent([head | tail]), do: do_merge_adjacent(tail, head, [])

  defp do_merge_adjacent([], current, acc) do
    Enum.reverse([current | acc])
  end

  defp do_merge_adjacent([{next_start, next_end} | rest], {cur_start, cur_end}, acc) do
    if Time.compare(next_start, cur_end) in [:lt, :eq] do
      # Overlapping or touching: merge into one continuous window
      new_end = if Time.compare(next_end, cur_end) == :gt, do: next_end, else: cur_end
      do_merge_adjacent(rest, {cur_start, new_end}, acc)
    else
      do_merge_adjacent(rest, {next_start, next_end}, [{cur_start, cur_end} | acc])
    end
  end

  defp to_time_tuple({%Time{} = s, %Time{} = e}), do: {s, e}
  defp to_time_tuple(%{start_time: %Time{} = s, end_time: %Time{} = e}), do: {s, e}
  defp to_time_tuple(_), do: nil
end

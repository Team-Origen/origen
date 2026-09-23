defmodule Origen.Bookings.Snapshots do
  @moduledoc """
  Snapshot capture logic for booking operations.

  Captures consultation type name, duration_minutes, and price_ars at booking time.
  """

  alias Origen.ConsultationTypes.Catalog

  @type consultation_type :: %{
    id: binary(),
    reference: String.t(),
    name: String.t(),
    interval_count: pos_integer(),
    exact_price_ars: Decimal.t(),
    color: String.t(),
    status: :active | :inactive,
    agenda_interval_minutes: pos_integer()
  }

  @type snapshot :: %{
    name: String.t(),
    duration_minutes: pos_integer(),
    price_ars: Decimal.t()
  }

  @doc """
  Captures a snapshot from a consultation type for booking persistence.

  The snapshot includes:
  - name: normalized name of the consultation type
  - duration_minutes: interval_count * agenda_interval_minutes
  - price_ars: exact base price in ARS

  Color is NOT snapshotted (resolved at display time from current type).
  Agenda interval count is NOT conserved.
  """
  @spec capture_snapshot(consultation_type(), pos_integer()) :: {:ok, snapshot()} | {:error, :invalid_type}
  def capture_snapshot(type, agenda_interval_minutes) do
    with :active <- type.status,
         {:ok, duration} <- calculate_duration(type.interval_count, agenda_interval_minutes),
         {:ok, price} <- validate_price(type.exact_price_ars) do
      {:ok, %{
        name: type.name,
        duration_minutes: duration,
        price_ars: price
      }}
    else
      :inactive -> {:error, :inactive_type}
      {:error, :invalid_duration} -> {:error, :invalid_duration}
      {:error, :invalid_price} -> {:error, :invalid_price}
      _ -> {:error, :invalid_type}
    end
  end

  @doc """
  Calculates the duration in minutes from interval count and agenda interval.

  Duration must not exceed 240 minutes.
  """
  @spec calculate_duration(pos_integer(), pos_integer()) :: {:ok, pos_integer()} | {:error, :invalid_duration}
  def calculate_duration(interval_count, agenda_interval_minutes) do
    duration = interval_count * agenda_interval_minutes

    if duration > 0 and duration <= 240 do
      {:ok, duration}
    else
      {:error, :invalid_duration}
    end
  end

  @doc """
  Validates that the price is a valid non-negative Decimal with at most 2 decimal places.
  """
  @spec validate_price(Decimal.t()) :: {:ok, Decimal.t()} | {:error, :invalid_price}
  def validate_price(%Decimal{} = price) do
    cond do
      Decimal.compare(price, Decimal.new(0)) == :lt ->
        {:error, :invalid_price}

      # Check decimal places - convert to string and check
      decimal_str = Decimal.to_string(price)
      case String.split(decimal_str, ".") do
        [_int, frac] ->
          if String.length(frac) <= 2 do
            {:ok, price}
          else
            {:error, :invalid_price}
          end
        [_int] ->
          {:ok, price}
        _ ->
          {:error, :invalid_price}
      end
    end
  end

  def validate_price(_), do: {:error, :invalid_price}

  @doc """
  Fetches a consultation type from the catalog for booking validation.

  Returns the type with the professional's agenda interval included.
  """
  @spec fetch_type_for_booking(String.t(), String.t()) :: {:ok, consultation_type()} | {:error, term()}
  def fetch_type_for_booking(professional_reference, consultation_type_id) do
    with {:ok, %{
      consultation_types: types,
      agenda_interval_minutes: agenda_interval_minutes
    }} <- Catalog.execute({:list, %{professional_reference: professional_reference}}),
         type <- Enum.find(types, fn t -> t.id == consultation_type_id end),
         true <- type && type.status == :active do
      {:ok, Map.put(type, :agenda_interval_minutes, agenda_interval_minutes)}
    else
      _ -> {:error, :not_found_or_inactive}
    end
  end
end
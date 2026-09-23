defmodule Origen.ConsultationTypes do
  @moduledoc """
  Account-scoped consultation configuration for authenticated Professionals.

  Account ownership is temporary until Professional profiles are persisted. Callers provide the
  server-created internal session principal; ownership is always resolved again from persistence.
  """

  alias Origen.Repo

  @type configuration :: %{
          agenda_interval_minutes: pos_integer(),
          consultation_types: [map()]
        }
  @type validation_errors :: %{atom() => atom()}

  @protected_fields [
    :id,
    :owner_account_id,
    :account_id,
    :status,
    :inactive_duration_minutes,
    "id",
    "owner_account_id",
    "account_id",
    "status",
    "inactive_duration_minutes"
  ]

  @spec get_own_configuration(map()) ::
          {:ok, configuration()} | {:error, :unauthorized | :unavailable}
  def get_own_configuration(%{session_id: session_id, account_id: account_id})
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      owner_account_id = resolve_owner!(session_id, account_id)
      interval_minutes = get_or_create_agenda_settings!(owner_account_id, :lock)

      %{
        agenda_interval_minutes: interval_minutes,
        consultation_types: list_consultation_types!(owner_account_id)
      }
    end)
    |> case do
      {:ok, configuration} -> {:ok, configuration}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def get_own_configuration(_invalid_principal), do: {:error, :unauthorized}

  @spec create_type(map(), map()) ::
          {:ok, map()}
          | {:error, :unauthorized | :unavailable | {:validation, validation_errors()}}
  def create_type(%{session_id: session_id, account_id: account_id}, attrs)
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      owner_account_id = resolve_owner!(session_id, account_id)
      interval_minutes = get_or_create_agenda_settings!(owner_account_id, :lock)

      case validate_type_attrs(attrs, interval_minutes) do
        {:ok, validated_attrs} -> insert_consultation_type!(owner_account_id, validated_attrs)
        {:error, errors} -> Repo.rollback({:validation, errors})
      end
    end)
    |> case do
      {:ok, consultation_type} -> {:ok, consultation_type}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, {:validation, errors}} -> {:error, {:validation, errors}}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def create_type(_invalid_principal, _attrs), do: {:error, :unauthorized}

  @spec update_type(map(), String.t(), map()) ::
          {:ok, map()}
          | {:error,
             :unauthorized | :not_found | :unavailable | {:validation, validation_errors()}}
  def update_type(%{session_id: session_id, account_id: account_id}, consultation_type_id, attrs)
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      owner_account_id = resolve_owner!(session_id, account_id)
      interval_minutes = get_or_create_agenda_settings!(owner_account_id, :lock)
      persisted_id = lock_active_owned_type!(owner_account_id, consultation_type_id)

      case validate_type_attrs(attrs, interval_minutes) do
        {:ok, validated_attrs} ->
          update_consultation_type!(owner_account_id, persisted_id, validated_attrs)

        {:error, errors} ->
          Repo.rollback({:validation, errors})
      end
    end)
    |> case do
      {:ok, consultation_type} -> {:ok, consultation_type}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, :not_found} -> {:error, :not_found}
      {:error, {:validation, errors}} -> {:error, {:validation, errors}}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def update_type(_invalid_principal, _consultation_type_id, _attrs),
    do: {:error, :unauthorized}

  @spec deactivate_type(map(), String.t()) ::
          {:ok, map()} | {:error, :unauthorized | :not_found | :unavailable}
  def deactivate_type(
        %{session_id: session_id, account_id: account_id},
        consultation_type_id
      )
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      owner_account_id = resolve_owner!(session_id, account_id)
      interval_minutes = get_or_create_agenda_settings!(owner_account_id, :lock)
      persisted_id = lock_active_owned_type!(owner_account_id, consultation_type_id)

      deactivate_consultation_type!(owner_account_id, persisted_id, interval_minutes)
    end)
    |> case do
      {:ok, consultation_type} -> {:ok, consultation_type}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, :not_found} -> {:error, :not_found}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def deactivate_type(_invalid_principal, _consultation_type_id),
    do: {:error, :unauthorized}

  @spec reactivate_type(map(), String.t()) ::
          {:ok, map()}
          | {:error,
             :unauthorized
             | :not_found
             | :unavailable
             | {:incompatible, %{name: String.t(), prospective_duration_minutes: pos_integer()}}}
  def reactivate_type(
        %{session_id: session_id, account_id: account_id},
        consultation_type_id
      )
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      owner_account_id = resolve_owner!(session_id, account_id)
      interval_minutes = get_or_create_agenda_settings!(owner_account_id, :lock)

      %{id: persisted_id, name: name, interval_count: interval_count} =
        lock_inactive_owned_type!(owner_account_id, consultation_type_id)

      prospective_duration_minutes = interval_count * interval_minutes

      if prospective_duration_minutes <= 240 do
        reactivate_consultation_type!(owner_account_id, persisted_id)
      else
        Repo.rollback(
          {:incompatible,
           %{name: name, prospective_duration_minutes: prospective_duration_minutes}}
        )
      end
    end)
    |> case do
      {:ok, consultation_type} -> {:ok, consultation_type}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, :not_found} -> {:error, :not_found}
      {:error, {:incompatible, evidence}} -> {:error, {:incompatible, evidence}}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def reactivate_type(_invalid_principal, _consultation_type_id),
    do: {:error, :unauthorized}

  @spec apply_agenda_interval(map(), integer() | String.t()) ::
          {:ok, configuration()}
          | {:error,
             :unauthorized
             | :unavailable
             | {:validation, %{agenda_interval_minutes: :invalid}}
             | {:incompatible,
                %{
                  maximum_interval_count: pos_integer(),
                  blockers: [
                    %{
                      id: String.t(),
                      name: String.t(),
                      interval_count: pos_integer(),
                      prospective_duration_minutes: pos_integer()
                    }
                  ]
                }}}
  def apply_agenda_interval(
        %{session_id: session_id, account_id: account_id},
        proposed_interval
      )
      when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      owner_account_id = resolve_owner!(session_id, account_id)
      current_interval = get_or_create_agenda_settings!(owner_account_id, :lock)

      case validate_agenda_interval(proposed_interval) do
        {:ok, interval_minutes} ->
          active_types = lock_active_owned_types!(owner_account_id)
          blockers = interval_blockers(active_types, interval_minutes)

          availability_boundaries =
            availability_interval_blockers!(owner_account_id, interval_minutes)

          if blockers == [] and availability_boundaries == [] do
            apply_interval_if_changed!(owner_account_id, current_interval, interval_minutes)

            %{
              agenda_interval_minutes: interval_minutes,
              consultation_types: list_consultation_types!(owner_account_id)
            }
          else
            evidence =
              %{}
              |> maybe_put_type_blockers(blockers, interval_minutes)
              |> maybe_put_availability_boundaries(availability_boundaries)

            Repo.rollback({:incompatible, evidence})
          end

        :error ->
          Repo.rollback({:validation, %{agenda_interval_minutes: :invalid}})
      end
    end)
    |> case do
      {:ok, configuration} -> {:ok, configuration}
      {:error, :unauthorized} -> {:error, :unauthorized}
      {:error, {:validation, errors}} -> {:error, {:validation, errors}}
      {:error, {:incompatible, evidence}} -> {:error, {:incompatible, evidence}}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def apply_agenda_interval(_invalid_principal, _proposed_interval),
    do: {:error, :unauthorized}

  defp resolve_owner!(session_id, account_id) do
    query = """
    SELECT accounts.id
    FROM internal_account_sessions AS sessions
    JOIN internal_accounts AS accounts ON accounts.id = sessions.account_id
    WHERE sessions.id = $1
      AND sessions.account_id = $2
      AND sessions.revoked_at IS NULL
      AND clock_timestamp() <= sessions.issued_at
        + sessions.max_duration_seconds * interval '1 second'
      AND clock_timestamp() <= sessions.last_activity_at
        + sessions.idle_timeout_seconds * interval '1 second'
      AND accounts.role = 'professional'
      AND accounts.state = 'active'
    FOR SHARE OF sessions, accounts
    """

    case Repo.query!(query, [session_id, account_id]).rows do
      [[resolved_account_id]] -> resolved_account_id
      [] -> Repo.rollback(:unauthorized)
    end
  end

  defp get_or_create_agenda_settings!(owner_account_id, lock) do
    Repo.query!(
      """
      INSERT INTO agenda_settings (owner_account_id)
      VALUES ($1)
      ON CONFLICT (owner_account_id) DO NOTHING
      """,
      [owner_account_id]
    )

    lock_clause = if lock == :lock, do: " FOR UPDATE", else: ""

    [[interval_minutes]] =
      Repo.query!(
        "SELECT interval_minutes FROM agenda_settings WHERE owner_account_id = $1#{lock_clause}",
        [owner_account_id]
      ).rows

    interval_minutes
  end

  defp list_consultation_types!(owner_account_id) do
    Repo.query!(
      """
      SELECT id, name, exact_price_ars, color, interval_count, status,
             inactive_duration_minutes
      FROM consultation_types
      WHERE owner_account_id = $1
      ORDER BY created_at, id
      """,
      [owner_account_id]
    ).rows
    |> Enum.map(&row_to_consultation_type/1)
  end

  defp validate_type_attrs(attrs, interval_minutes) when is_map(attrs) do
    if Enum.any?(@protected_fields, &Map.has_key?(attrs, &1)) do
      {:error, %{base: :protected_fields}}
    else
      validations = %{
        name: validate_name(fetch_attr(attrs, :name)),
        exact_price_ars: validate_price(fetch_attr(attrs, :exact_price_ars)),
        color: validate_color(fetch_attr(attrs, :color)),
        interval_count:
          validate_interval_count(fetch_attr(attrs, :interval_count), interval_minutes)
      }

      errors =
        Enum.reduce(validations, %{}, fn
          {field, {:error, reason}}, errors -> Map.put(errors, field, reason)
          {_field, {:ok, _value}}, errors -> errors
        end)

      if map_size(errors) == 0 do
        {:ok, Map.new(validations, fn {field, {:ok, value}} -> {field, value} end)}
      else
        {:error, errors}
      end
    end
  end

  defp validate_type_attrs(_attrs, _interval_minutes), do: {:error, %{base: :invalid}}

  defp validate_name(name) when is_binary(name) do
    normalized_name = String.trim(name)

    cond do
      normalized_name == "" -> {:error, :required}
      String.length(normalized_name) > 32 -> {:error, :too_long}
      true -> {:ok, normalized_name}
    end
  end

  defp validate_name(_name), do: {:error, :required}

  defp validate_price(value)
       when is_binary(value) or is_integer(value) or is_struct(value, Decimal) do
    case Decimal.cast(value) do
      {:ok, decimal} -> validate_decimal(decimal)
      :error -> {:error, :invalid}
    end
  end

  defp validate_price(_value), do: {:error, :invalid}

  defp validate_decimal(decimal) do
    cond do
      Decimal.nan?(decimal) or Decimal.inf?(decimal) -> {:error, :invalid}
      Decimal.compare(decimal, Decimal.new(0)) == :lt -> {:error, :nonnegative}
      Decimal.scale(decimal) > 2 -> {:error, :scale}
      true -> {:ok, decimal}
    end
  end

  defp validate_color(color) when is_binary(color) do
    if Regex.match?(~r/^#[0-9A-F]{6}$/, color), do: {:ok, color}, else: {:error, :invalid}
  end

  defp validate_color(_color), do: {:error, :invalid}

  defp validate_interval_count(value, interval_minutes) do
    with {:ok, count} <- parse_integer(value),
         maximum = min(10, div(240, interval_minutes)),
         true <- count in 1..maximum do
      {:ok, count}
    else
      _invalid -> {:error, :invalid}
    end
  end

  defp parse_integer(value) when is_integer(value), do: {:ok, value}

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _invalid -> :error
    end
  end

  defp parse_integer(_value), do: :error

  defp validate_agenda_interval(value) do
    with {:ok, interval_minutes} <- parse_canonical_integer(value),
         true <- interval_minutes in 5..240,
         true <- rem(interval_minutes, 5) == 0 do
      {:ok, interval_minutes}
    else
      _invalid -> :error
    end
  end

  defp parse_canonical_integer(value) when is_integer(value), do: {:ok, value}

  defp parse_canonical_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} ->
        if value == Integer.to_string(integer), do: {:ok, integer}, else: :error

      _invalid ->
        :error
    end
  end

  defp parse_canonical_integer(_value), do: :error

  defp fetch_attr(attrs, field) do
    case Map.fetch(attrs, field) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(field))
    end
  end

  defp insert_consultation_type!(owner_account_id, attrs) do
    id = Ecto.UUID.generate()

    [row] =
      Repo.query!(
        """
        INSERT INTO consultation_types
          (id, owner_account_id, name, exact_price_ars, color, interval_count,
           status, inactive_duration_minutes)
        VALUES ($1, $2, $3, $4, $5, $6, 'active', NULL)
        RETURNING id, name, exact_price_ars, color, interval_count, status,
                  inactive_duration_minutes
        """,
        [
          Ecto.UUID.dump!(id),
          owner_account_id,
          attrs.name,
          attrs.exact_price_ars,
          attrs.color,
          attrs.interval_count
        ]
      ).rows

    row_to_consultation_type(row)
  end

  defp lock_active_owned_type!(owner_account_id, consultation_type_id) do
    with {:ok, ^consultation_type_id} <- Ecto.UUID.cast(consultation_type_id),
         persisted_id <- Ecto.UUID.dump!(consultation_type_id),
         [[^persisted_id]] <-
           Repo.query!(
             """
             SELECT id
             FROM consultation_types
             WHERE id = $1 AND owner_account_id = $2 AND status = 'active'
             FOR UPDATE
             """,
             [persisted_id, owner_account_id]
           ).rows do
      persisted_id
    else
      _missing_or_invalid -> Repo.rollback(:not_found)
    end
  end

  defp lock_inactive_owned_type!(owner_account_id, consultation_type_id) do
    with {:ok, ^consultation_type_id} <- Ecto.UUID.cast(consultation_type_id),
         persisted_id <- Ecto.UUID.dump!(consultation_type_id),
         [[^persisted_id, name, interval_count]] <-
           Repo.query!(
             """
             SELECT id, name, interval_count
             FROM consultation_types
             WHERE id = $1 AND owner_account_id = $2 AND status = 'inactive'
             FOR UPDATE
             """,
             [persisted_id, owner_account_id]
           ).rows do
      %{id: persisted_id, name: name, interval_count: interval_count}
    else
      _missing_or_invalid -> Repo.rollback(:not_found)
    end
  end

  defp lock_active_owned_types!(owner_account_id) do
    Repo.query!(
      """
      SELECT id, name, interval_count
      FROM consultation_types
      WHERE owner_account_id = $1 AND status = 'active'
      ORDER BY created_at, id
      FOR UPDATE
      """,
      [owner_account_id]
    ).rows
    |> Enum.map(fn [id, name, interval_count] ->
      %{id: Ecto.UUID.load!(id), name: name, interval_count: interval_count}
    end)
  end

  defp interval_blockers(active_types, interval_minutes) do
    active_types
    |> Enum.map(fn type ->
      Map.put(type, :prospective_duration_minutes, type.interval_count * interval_minutes)
    end)
    |> Enum.filter(&(&1.prospective_duration_minutes > 240))
  end

  defp availability_interval_blockers!(owner_account_id, interval_minutes) do
    [[week]] =
      Repo.query!(
        "SELECT weekly_availability FROM agenda_settings WHERE owner_account_id = $1",
        [owner_account_id]
      ).rows

    ~w(monday tuesday wednesday thursday friday saturday sunday)
    |> Enum.flat_map(fn day ->
      week
      |> Map.fetch!(day)
      |> Enum.flat_map(fn window ->
        [Map.fetch!(window, "start"), Map.fetch!(window, "end")]
        |> Enum.filter(&(rem(time_to_minutes(&1), interval_minutes) != 0))
        |> Enum.map(&"#{day} #{&1}")
      end)
    end)
  end

  defp time_to_minutes(value) do
    [hour, minute] = value |> String.split(":") |> Enum.map(&String.to_integer/1)
    hour * 60 + minute
  end

  defp maybe_put_type_blockers(evidence, [], _interval_minutes), do: evidence

  defp maybe_put_type_blockers(evidence, blockers, interval_minutes) do
    Map.merge(evidence, %{
      maximum_interval_count: min(10, div(240, interval_minutes)),
      blockers: blockers
    })
  end

  defp maybe_put_availability_boundaries(evidence, []), do: evidence

  defp maybe_put_availability_boundaries(evidence, boundaries),
    do: Map.put(evidence, :availability_boundaries, boundaries)

  defp apply_interval_if_changed!(_owner_account_id, interval_minutes, interval_minutes), do: :ok

  defp apply_interval_if_changed!(owner_account_id, _current_interval, interval_minutes) do
    Repo.query!(
      """
      UPDATE agenda_settings
      SET interval_minutes = $2, updated_at = clock_timestamp()
      WHERE owner_account_id = $1
      """,
      [owner_account_id, interval_minutes]
    )

    :ok
  end

  defp update_consultation_type!(owner_account_id, persisted_id, attrs) do
    [row] =
      Repo.query!(
        """
        UPDATE consultation_types
        SET name = $3, exact_price_ars = $4, color = $5, interval_count = $6,
            updated_at = clock_timestamp()
        WHERE id = $1 AND owner_account_id = $2 AND status = 'active'
        RETURNING id, name, exact_price_ars, color, interval_count, status,
                  inactive_duration_minutes
        """,
        [
          persisted_id,
          owner_account_id,
          attrs.name,
          attrs.exact_price_ars,
          attrs.color,
          attrs.interval_count
        ]
      ).rows

    row_to_consultation_type(row)
  end

  defp deactivate_consultation_type!(owner_account_id, persisted_id, interval_minutes) do
    [row] =
      Repo.query!(
        """
        UPDATE consultation_types
        SET status = 'inactive',
            inactive_duration_minutes = interval_count * $3,
            updated_at = clock_timestamp()
        WHERE id = $1 AND owner_account_id = $2 AND status = 'active'
        RETURNING id, name, exact_price_ars, color, interval_count, status,
                  inactive_duration_minutes
        """,
        [persisted_id, owner_account_id, interval_minutes]
      ).rows

    row_to_consultation_type(row)
  end

  defp reactivate_consultation_type!(owner_account_id, persisted_id) do
    [row] =
      Repo.query!(
        """
        UPDATE consultation_types
        SET status = 'active', inactive_duration_minutes = NULL,
            updated_at = clock_timestamp()
        WHERE id = $1 AND owner_account_id = $2 AND status = 'inactive'
        RETURNING id, name, exact_price_ars, color, interval_count, status,
                  inactive_duration_minutes
        """,
        [persisted_id, owner_account_id]
      ).rows

    row_to_consultation_type(row)
  end

  defp row_to_consultation_type([
         id,
         name,
         price,
         color,
         interval_count,
         status,
         inactive_duration
       ]) do
    %{
      id: Ecto.UUID.load!(id),
      name: name,
      exact_price_ars: price,
      color: color,
      interval_count: interval_count,
      status: status_atom(status),
      inactive_duration_minutes: inactive_duration
    }
  end

  defp status_atom("active"), do: :active
  defp status_atom("inactive"), do: :inactive
end

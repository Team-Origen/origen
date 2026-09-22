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

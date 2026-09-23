defmodule Origen.Availability do
  @moduledoc """
  Own regular availability configuration for authenticated Professionals.

  Ownership and authorization are revalidated from persistence for every operation.
  """

  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.Repo
  alias Origen.Sessions

  @days ~w(monday tuesday wednesday thursday friday saturday sunday)a
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

  defp transaction_result({:ok, {:error, :unauthorized}}), do: {:error, :unauthorized}
  defp transaction_result({:ok, result}), do: {:ok, result}
  defp transaction_result({:error, :unauthorized}), do: {:error, :unauthorized}
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

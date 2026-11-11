defmodule Origen.Booking.EconomicSummary do
  @moduledoc """
  Read-only economic summaries scoped to one active Professional.

  The actor is derived from a revalidated internal session. Professionals can
  request only their own account; Secretaries can request one existing active
  Professional at a time. The aggregate uses the appointment's current final
  price and current payment mark, never payment history or catalog snapshots.
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Authorization
  alias Origen.Authorization.{Fact, Request}
  alias Origen.Booking.{Appointment, EconomicSummaryPeriod, Payment}
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @staff_roles [:professional, :secretary]

  @type result :: %{
          professional: %{id: pos_integer()},
          period: EconomicSummaryPeriod.t(),
          paid: Decimal.t(),
          pending: Decimal.t(),
          total: Decimal.t()
        }

  @doc "Returns one authorized Professional's exact ARS summary for a validated period."
  @spec read(map() | InternalSession.t(), term(), term()) ::
          {:ok, result()}
          | {:error,
             :unauthorized
             | :invalid_professional_selection
             | EconomicSummaryPeriod.error()}
  def read(principal, professional_id, period_params) do
    with {:ok, actor} <- resolve_principal(principal),
         {:ok, selected_id} <- validate_selection(professional_id),
         :ok <- authorize(actor, selected_id),
         :ok <- ensure_existing_professional(selected_id),
         {:ok, period} <- EconomicSummaryPeriod.validate(period_params),
         totals <- aggregate(selected_id, period) do
      {:ok,
       %{
         professional: %{id: selected_id},
         period: period,
         paid: totals.paid,
         pending: totals.pending,
         total: Decimal.add(totals.paid, totals.pending)
       }}
    end
  end

  defp validate_selection(id) when is_integer(id) and id > 0, do: {:ok, id}
  defp validate_selection(_invalid), do: {:error, :invalid_professional_selection}

  defp ensure_existing_professional(professional_id) do
    query =
      from(a in "internal_accounts",
        where: a.id == ^professional_id and a.role == "professional" and a.state == "active",
        select: a.id
      )

    case Repo.one(query) do
      ^professional_id -> :ok
      _ -> {:error, :invalid_professional_selection}
    end
  end

  defp authorize(%{role: :professional, account_id: actor_id}, professional_id)
       when actor_id == professional_id do
    authorize_matrix(:professional, %{owner_matches_actor: true})
  end

  defp authorize(%{role: :secretary}, _professional_id),
    do: authorize_matrix(:secretary, %{center_scope: true})

  defp authorize(_actor, _professional_id), do: {:error, :unauthorized}

  defp authorize_matrix(role, target) do
    request =
      Request.new(
        operation: Fact.known(:read_economic_summary),
        subject: Fact.known({:role, role}),
        account_state: Fact.known(:active),
        target: Fact.known(target),
        scope: Fact.known(%{authenticated: true})
      )

    case Authorization.decide(request) do
      {:allow, _rule} -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  defp aggregate(professional_id, %EconomicSummaryPeriod{} = period) do
    query =
      from(a in Appointment,
        join: p in Payment,
        on: p.appointment_id == a.id,
        where: a.professional_account_id == ^professional_id,
        where: a.start_time >= ^period.start_at and a.start_time < ^period.end_at,
        select: %{
          paid:
            fragment(
              "COALESCE(SUM(CASE WHEN ? = 'paid' THEN ? ELSE 0 END), 0)",
              p.status,
              a.final_price_ars
            ),
          pending:
            fragment(
              "COALESCE(SUM(CASE WHEN ? = 'pending' AND ? IN ('confirmed', 'attended') THEN ? ELSE 0 END), 0)",
              p.status,
              a.status,
              a.final_price_ars
            )
        }
      )

    Repo.one(query)
  end

  defp resolve_principal(%InternalSession{id: session_id, account_id: account_id}),
    do: resolve_principal(%{session_id: session_id, account_id: account_id})

  defp resolve_principal(%{session_id: session_id, account_id: account_id})
       when is_integer(session_id) and is_integer(account_id) do
    case Sessions.revalidate_principal(session_id, account_id) do
      {:ok, %{account_id: resolved_id, role: role}} when role in @staff_roles ->
        {:ok, %{role: role, account_id: resolved_id}}

      _ ->
        {:error, :unauthorized}
    end
  end

  defp resolve_principal(_principal), do: {:error, :unauthorized}
end

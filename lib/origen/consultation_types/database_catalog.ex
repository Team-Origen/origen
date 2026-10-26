defmodule Origen.ConsultationTypes.DatabaseCatalog do
  @moduledoc "Read-only public consultation snapshots for the persisted Patient calendar."
  @behaviour Origen.ConsultationTypes.Catalog

  alias Origen.Repo

  @impl true
  def execute({:list, %{professional_reference: reference}}) when is_binary(reference) do
    with {owner_id, ""} when owner_id > 0 and owner_id <= 9_223_372_036_854_775_807 <-
           Integer.parse(reference) do
      snapshot(owner_id, reference)
    else
      _ -> {:error, :invalid_professional}
    end
  end

  def execute(_operation), do: {:error, :invalid_professional}

  defp snapshot(owner_id, reference) do
    case Repo.query(
           """
           SELECT s.interval_minutes, t.id, t.name, t.interval_count, t.exact_price_ars
           FROM agenda_settings s
           LEFT JOIN consultation_types t
             ON t.owner_account_id = s.owner_account_id AND t.status = 'active'
           WHERE s.owner_account_id = $1
           ORDER BY t.created_at, t.id
           """,
           [owner_id]
         ) do
      {:ok, %{rows: [[interval | _] | _] = rows}} ->
        types =
          for [_interval, id, name, count, price] <- rows, not is_nil(id) do
            %{
              id: Ecto.UUID.load!(id),
              name: name,
              interval_count: count,
              exact_price_ars: price,
              status: :active
            }
          end

        {:ok,
         %{
           source: :database,
           professional_reference: reference,
           agenda_interval_minutes: interval,
           consultation_types: types
         }}

      _ ->
        {:error, :unavailable}
    end
  end
end

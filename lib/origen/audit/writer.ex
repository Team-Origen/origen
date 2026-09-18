defmodule Origen.Audit.Writer do
  @moduledoc false

  alias Ecto.Multi
  alias Origen.Audit.Events
  alias Origen.Repo

  @audit_rules [:a_01, :sys_01]
  @insert """
  INSERT INTO public.audit_events
    (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
  VALUES ($1, $2, $3, $4, $5, $6)
  RETURNING id, actor_kind, actor_ref, event, entity_kind, entity_ref, result, recorded_at
  """

  @spec append(Events.t(), Origen.Authorization.Decision.t()) ::
          {:ok, map()} | {:error, :unauthorized | :audit_unavailable}
  def append(event, {:allow, rule}) when rule in @audit_rules do
    if Events.persistable?(event), do: insert(event), else: {:error, :unauthorized}
  end

  def append(_event, _decision), do: {:error, :unauthorized}

  @spec append_to_multi(Multi.t(), Events.t(), Origen.Authorization.Decision.t()) :: Multi.t()
  def append_to_multi(%Multi{} = multi, event, decision) do
    Multi.run(multi, :audit_event, fn _repo, _changes -> append(event, decision) end)
  end

  defp insert(event) do
    values = [
      event.actor_kind,
      event.actor_ref,
      event.event,
      event.entity_kind,
      event.entity_ref,
      event.result
    ]

    case Ecto.Adapters.SQL.query(Repo, @insert, values) do
      {:ok, %{rows: [[id, actor_kind, actor_ref, name, entity_kind, entity_ref, result, time]]}} ->
        {:ok,
         %{
           id: id,
           actor_kind: actor_kind,
           actor_ref: actor_ref,
           event: name,
           entity_kind: entity_kind,
           entity_ref: entity_ref,
           result: result,
           recorded_at: time
         }}

      {:error, _reason} ->
        {:error, :audit_unavailable}
    end
  end
end

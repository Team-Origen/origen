defmodule Origen.Booking.Expiry do
  @moduledoc """
  Expires unresolved requested appointments at their start time.

  Expiry is deliberately independent from the later lifecycle operations. It
  updates only `requested` rows, keeps the appointment row as history, and
  writes its minimized audit event in the same transaction.
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias Origen.Booking.Appointment
  alias Origen.Repo

  @audit_event_insert """
  INSERT INTO public.audit_events
    (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
  VALUES ($1, $2, $3, $4, $5, $6)
  """

  @type sweep_result :: %{expired_count: non_neg_integer(), appointment_ids: [integer()]}

  @doc """
  Expires every requested appointment whose start is at or before `now`.

  The default clock is obtained inside the operation. The optional `:now`
  keyword is an infrastructure/testing injection and is not read from a
  principal or appointment attributes.
  """
  @spec expire_due_requested(keyword()) :: {:ok, sweep_result()} | {:error, term()}
  def expire_due_requested(opts \\ [])

  def expire_due_requested(opts) when is_list(opts) do
    with {:ok, now} <- resolve_now(opts) do
      Repo.transaction(fn ->
        query =
          from(a in Appointment,
            where: a.status == "requested" and a.start_time <= ^now,
            order_by: [asc: a.start_time, asc: a.id],
            lock: "FOR UPDATE SKIP LOCKED"
          )

        query
        |> Repo.all()
        |> Enum.reduce(%{expired_count: 0, appointment_ids: []}, fn appointment, result ->
          case expire_locked(appointment, now) do
            {:ok, expired} ->
              %{
                expired_count: result.expired_count + 1,
                appointment_ids: result.appointment_ids ++ [expired.id]
              }

            {:error, reason} ->
              Repo.rollback(reason)
          end
        end)
      end)
    end
  end

  def expire_due_requested(_opts), do: {:error, :invalid_expiry_options}

  @doc "Alias for the public expiry sweep used by runtime and query triggers."
  @spec sweep(keyword()) :: {:ok, sweep_result()} | {:error, term()}
  def sweep(opts \\ []), do: expire_due_requested(opts)

  @doc false
  @spec expire_locked(Appointment.t(), DateTime.t()) :: {:ok, Appointment.t()} | {:error, term()}
  def expire_locked(%Appointment{status: "requested"} = appointment, %DateTime{} = now) do
    if DateTime.compare(appointment.start_time, now) != :gt do
      appointment
      |> Appointment.changeset(%{status: "expired"})
      |> Repo.update()
      |> case do
        {:ok, expired} = result ->
          append_expiry_audit_event!(expired)
          result

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, appointment}
    end
  end

  def expire_locked(%Appointment{} = appointment, %DateTime{} = _now), do: {:ok, appointment}

  defp resolve_now(opts) do
    case Keyword.get(opts, :now) do
      nil -> {:ok, DateTime.utc_now()}
      %DateTime{} = now -> {:ok, now}
      _invalid -> {:error, :invalid_expiry_now}
    end
  end

  defp append_expiry_audit_event!(%Appointment{} = appointment) do
    values = [
      "system",
      "system:appointment_expiry",
      "appointment_expired",
      "appointment",
      "appointment:#{appointment.id}",
      "succeeded"
    ]

    case SQL.query(Repo, @audit_event_insert, values) do
      {:ok, _result} -> :ok
      {:error, _reason} -> Repo.rollback(:expiry_audit_failed)
    end
  end
end

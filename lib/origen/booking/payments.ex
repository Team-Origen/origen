defmodule Origen.Booking.Payments do
  @moduledoc """
  Authorized appointment price and payment-state projections.

  T1 owns the pending payment row, the final-price correction operation and
  patient-safe reads. Registration and payment correction history are reserved
  for the next slices; the payment action table is created now so those slices
  can append immutable actions without changing appointment snapshots.
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Authorization.Policy
  alias Origen.Booking.{Appointment, Payment}
  alias Origen.Patients
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @staff_roles [:professional, :secretary]
  @audit_insert """
  INSERT INTO public.audit_events
    (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
  VALUES ($1, $2, 'appointment_price_updated', 'appointment', $3, 'succeeded')
  """

  @doc "Returns the authorized final-price/payment-state projection."
  @spec read(map() | InternalSession.t(), integer()) ::
          {:ok, map()} | {:error, :unauthorized | :payment_not_initialized}
  def read(principal, appointment_id) when is_integer(appointment_id) do
    with {:ok, actor} <- resolve_principal(principal),
         true <- Policy.payment_allowed?(actor.role, :read_payment),
         {:ok, projection} <- query_projection(actor, appointment_id) do
      {:ok, projection}
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def read(_principal, _appointment_id), do: {:error, :unauthorized}

  @doc "Updates one unpaid appointment's final price under a row lock."
  @spec update_price(map() | InternalSession.t(), integer(), term()) ::
          {:ok, map()} | {:error, atom()}
  def update_price(principal, appointment_id, value) when is_integer(appointment_id) do
    with {:ok, actor} <- resolve_principal(principal),
         true <- Policy.payment_allowed?(actor.role, :edit_appointment_price),
         {:ok, price} <- normalize_price(value) do
      do_update_price(actor, appointment_id, price)
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_price(_principal, _appointment_id, _value), do: {:error, :unauthorized}

  defp do_update_price(actor, appointment_id, price) do
    Repo.transaction(fn ->
      appointment = lock_appointment!(appointment_id)
      authorize_scope!(actor, appointment)
      payment = lock_payment!(appointment_id)

      if payment.status == "paid" do
        Repo.rollback(:payment_already_paid)
      end

      updated =
        appointment
        |> Ecto.Changeset.change(final_price_ars: price)
        |> Repo.update()
        |> case do
          {:ok, value} -> value
          {:error, changeset} -> Repo.rollback({:validation_error, changeset})
        end

      append_price_audit!(actor, updated)

      %{
        appointment_id: updated.id,
        final_price_ars: updated.final_price_ars,
        payment_status: payment.status
      }
    end)
  end

  defp query_projection(actor, appointment_id) do
    query =
      from(a in Appointment,
        join: p in Payment,
        on: p.appointment_id == a.id,
        where: a.id == ^appointment_id,
        select: %{
          appointment_id: a.id,
          final_price_ars: a.final_price_ars,
          payment_status: p.status,
          payment_method: p.method,
          paid_amount_ars: p.paid_amount_ars,
          paid_actor_kind: p.paid_actor_kind,
          paid_actor_ref: p.paid_actor_ref,
          paid_at: p.paid_at,
          patient_profile_id: a.patient_profile_id,
          professional_account_id: a.professional_account_id
        }
      )

    case Repo.one(query) do
      nil -> {:error, :unauthorized}
      projection -> authorize_and_project(actor, projection)
    end
  end

  defp authorize_and_project(%{role: :patient, patient_id: patient_id}, projection) do
    if projection.patient_profile_id == patient_id do
      {:ok,
       Map.take(projection, [
         :appointment_id,
         :final_price_ars,
         :payment_status
       ])}
    else
      {:error, :unauthorized}
    end
  end

  defp authorize_and_project(%{role: :professional, account_id: account_id}, projection) do
    if projection.professional_account_id == account_id do
      {:ok, staff_projection(projection)}
    else
      {:error, :unauthorized}
    end
  end

  defp authorize_and_project(%{role: :secretary}, projection),
    do: {:ok, staff_projection(projection)}

  defp authorize_and_project(_actor, _projection), do: {:error, :unauthorized}

  defp staff_projection(projection) do
    Map.drop(projection, [:patient_profile_id, :professional_account_id])
  end

  defp lock_appointment!(appointment_id) do
    case Repo.one(from(a in Appointment, where: a.id == ^appointment_id, lock: "FOR UPDATE")) do
      %Appointment{} = appointment -> appointment
      nil -> Repo.rollback(:unauthorized)
    end
  end

  defp lock_payment!(appointment_id) do
    case Repo.one(
           from(p in Payment, where: p.appointment_id == ^appointment_id, lock: "FOR UPDATE")
         ) do
      %Payment{} = payment -> payment
      nil -> Repo.rollback(:payment_not_initialized)
    end
  end

  defp authorize_scope!(%{role: :patient, patient_id: patient_id}, appointment) do
    if appointment.patient_profile_id == patient_id,
      do: :ok,
      else: Repo.rollback(:unauthorized)
  end

  defp authorize_scope!(%{role: :professional, account_id: account_id}, appointment) do
    if appointment.professional_account_id == account_id,
      do: :ok,
      else: Repo.rollback(:unauthorized)
  end

  defp authorize_scope!(%{role: :secretary}, _appointment), do: :ok
  defp authorize_scope!(_actor, _appointment), do: Repo.rollback(:unauthorized)

  defp normalize_price(value)
       when is_binary(value) or is_integer(value) or is_struct(value, Decimal) do
    case Decimal.cast(value) do
      {:ok, decimal} ->
        cond do
          Decimal.nan?(decimal) or Decimal.inf?(decimal) -> {:error, :invalid_final_price}
          Decimal.compare(decimal, Decimal.new(0)) == :lt -> {:error, :invalid_final_price}
          true -> {:ok, decimal}
        end

      :error ->
        {:error, :invalid_final_price}
    end
  end

  defp normalize_price(_value), do: {:error, :invalid_final_price}

  defp append_price_audit!(actor, appointment) do
    values = [audit_actor_kind(actor), audit_actor_ref(actor), "appointment:#{appointment.id}"]

    case Ecto.Adapters.SQL.query(Repo, @audit_insert, values) do
      {:ok, _result} -> :ok
      {:error, _reason} -> Repo.rollback(:audit_unavailable)
    end
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

  defp resolve_principal(%{patient_email: email, patient_authenticated_at: authenticated_at})
       when is_binary(email) do
    case Patients.verify_patient_session(email, authenticated_at) do
      {:ok, profile} -> {:ok, %{role: :patient, patient_id: profile.id}}
      _ -> {:error, :unauthorized}
    end
  end

  defp resolve_principal(_principal), do: {:error, :unauthorized}

  defp audit_actor_kind(%{role: :patient}), do: "patient"
  defp audit_actor_kind(%{role: role}), do: Atom.to_string(role)
  defp audit_actor_ref(%{role: :patient, patient_id: id}), do: "patient:#{id}"
  defp audit_actor_ref(%{account_id: id}), do: "internal_account:#{id}"
end

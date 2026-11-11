defmodule Origen.Booking.Lifecycle do
  @moduledoc """
  Authenticated appointment cancellation and operational history.

  The actor is derived from a revalidated server session (or the existing
  passwordless patient-session verifier). Appointment transitions lock the row,
  re-check scope and status, update metadata, and append audit in one transaction.
  """

  import Ecto.Query, only: [from: 2]

  alias Origen.Authorization.Policy
  alias Origen.Booking.Appointment
  alias Origen.Patients
  alias Origen.Repo
  alias Origen.Sessions
  alias Origen.Sessions.InternalSession

  @cancellable_statuses ~w(requested confirmed)
  @staff_roles [:professional, :secretary]
  @attendance_outcomes [:attended, :no_show]

  @audit_insert """
  INSERT INTO public.audit_events
    (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
  VALUES ($1, $2, $3, 'appointment', $4, 'succeeded')
  """

  @doc """
  Cancels a requested or confirmed appointment for an authenticated actor.

  Patient principals use `patient_email` and `patient_authenticated_at`, which
  are revalidated against the persisted patient access state. Internal
  principals use `session_id` and `account_id`, which are revalidated through
  `Origen.Sessions.revalidate_principal/2`. Role and identity fields supplied by
  a caller are never trusted.

  Staff must provide a nonblank `:reason`; patients do not need a reason and may
  cancel only their own requested or confirmed appointments strictly before the
  start. Staff scope is agenda-based and has no patient time cutoff.
  """
  @spec cancel(map() | InternalSession.t(), integer(), map() | keyword() | binary() | nil) ::
          {:ok, Appointment.t()} | {:error, term()}
  def cancel(principal, appointment_id, attrs \\ [])

  def cancel(principal, appointment_id, attrs) when is_integer(appointment_id) do
    with {:ok, options} <- normalize_options(attrs),
         {:ok, actor} <- resolve_principal(principal),
         true <- Policy.lifecycle_allowed?(actor.role, :cancel_appointment) do
      do_cancel(actor, appointment_id, options)
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def cancel(_principal, _appointment_id, _attrs), do: {:error, :unauthorized}

  @doc "Alias with the public domain verb used by the Booking context."
  def cancel_appointment(principal, appointment_id, attrs \\ []),
    do: cancel(principal, appointment_id, attrs)

  @doc """
  Records attendance or no-show for a confirmed appointment.

  Professionals are limited to their own agenda and secretaries may operate on
  any centre agenda. The appointment row is locked and the active session is
  revalidated before the transition. No product time window or terminal
  correction workflow is applied.
  """
  @spec record_attendance(
          map() | InternalSession.t(),
          integer(),
          :attended | :no_show | String.t(),
          keyword()
        ) :: {:ok, Appointment.t()} | {:error, term()}
  def record_attendance(principal, appointment_id, outcome, opts \\ [])

  def record_attendance(principal, appointment_id, outcome, opts)
      when is_integer(appointment_id) do
    with {:ok, options} <- normalize_options(opts),
         {:ok, normalized_outcome} <- normalize_attendance_outcome(outcome),
         {:ok, actor} <- resolve_principal(principal),
         true <- Policy.lifecycle_allowed?(actor.role, :record_attendance) do
      do_record_attendance(actor, appointment_id, normalized_outcome, options)
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def record_attendance(_principal, _appointment_id, _outcome, _opts),
    do: {:error, :unauthorized}

  @doc """
  Returns non-clinical operational history filtered in SQL by the revalidated actor.

  Patients see their own appointments, professionals see only their own agenda,
  and secretaries see all agendas. Administrators and malformed or stale
  principals are denied; expired and cancelled rows remain queryable.
  """
  @spec history(map() | InternalSession.t(), map() | keyword()) ::
          {:ok, [map()]} | {:error, :unauthorized}
  def history(principal, _opts \\ %{}) do
    with {:ok, actor} <- resolve_principal(principal),
         true <- Policy.lifecycle_allowed?(actor.role, :read_appointment_history) do
      {:ok, query_history(actor)}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp do_cancel(actor, appointment_id, options) do
    reason = cancellation_reason(actor, options)

    with :ok <- reason do
      Repo.transaction(fn ->
        appointment = lock_appointment!(appointment_id)

        now =
          case resolve_now(options) do
            {:ok, value} -> value
            {:error, reason} -> Repo.rollback(reason)
          end

        authorize_scope!(actor, appointment)
        ensure_cancellable!(appointment)
        ensure_patient_time!(actor, appointment, now)

        attrs = %{
          status: "cancelled",
          cancellation_origin: Atom.to_string(actor.role),
          cancellation_reason: cancellation_reason_value(actor, options)
        }

        updated =
          appointment
          |> Appointment.changeset(attrs)
          |> Repo.update()
          |> case do
            {:ok, value} -> value
            {:error, changeset} -> Repo.rollback({:validation_error, changeset})
          end

        append_audit!(actor, updated, "appointment_cancelled", options)
        updated
      end)
    end
  end

  defp do_record_attendance(actor, appointment_id, outcome, options) do
    Repo.transaction(fn ->
      appointment = lock_appointment!(appointment_id)
      authorize_scope!(actor, appointment)
      ensure_attendance_allowed!(appointment)

      updated =
        appointment
        |> Appointment.changeset(%{status: Atom.to_string(outcome)})
        |> Repo.update()
        |> case do
          {:ok, value} -> value
          {:error, changeset} -> Repo.rollback({:validation_error, changeset})
        end

      append_audit!(actor, updated, attendance_audit_event(outcome), options)
      updated
    end)
  end

  defp cancellation_reason(%{role: role}, _options) when role == :patient, do: :ok

  defp cancellation_reason(%{role: role}, options) when role in @staff_roles do
    case cancellation_reason_value(%{role: role}, options) do
      reason when is_binary(reason) ->
        if String.trim(reason) == "", do: {:error, :cancellation_reason_required}, else: :ok

      _ ->
        {:error, :cancellation_reason_required}
    end
  end

  defp cancellation_reason(_actor, _options), do: {:error, :unauthorized}

  defp cancellation_reason_value(%{role: :patient}, _options), do: nil

  defp cancellation_reason_value(%{role: role}, options) when role in @staff_roles do
    option(options, :reason)
    |> case do
      reason when is_binary(reason) -> String.trim(reason)
      other -> other
    end
  end

  defp lock_appointment!(appointment_id) do
    case Repo.one(from(a in Appointment, where: a.id == ^appointment_id, lock: "FOR UPDATE")) do
      %Appointment{} = appointment -> appointment
      nil -> Repo.rollback(:appointment_not_found)
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

  defp ensure_cancellable!(%Appointment{status: status}) when status in @cancellable_statuses,
    do: :ok

  defp ensure_cancellable!(_appointment), do: Repo.rollback(:invalid_status_transition)

  defp ensure_patient_time!(%{role: :patient}, appointment, now) do
    if DateTime.compare(appointment.start_time, now) == :gt,
      do: :ok,
      else: Repo.rollback(:patient_cancellation_not_allowed)
  end

  defp ensure_patient_time!(_actor, _appointment, _now), do: :ok

  defp normalize_attendance_outcome(outcome) when outcome in @attendance_outcomes,
    do: {:ok, outcome}

  defp normalize_attendance_outcome(outcome) when is_binary(outcome) do
    case outcome do
      "attended" -> {:ok, :attended}
      "no_show" -> {:ok, :no_show}
      _ -> {:error, :invalid_attendance_outcome}
    end
  end

  defp normalize_attendance_outcome(_outcome), do: {:error, :invalid_attendance_outcome}

  defp ensure_attendance_allowed!(%Appointment{status: "confirmed"}), do: :ok
  defp ensure_attendance_allowed!(_appointment), do: Repo.rollback(:invalid_status_transition)

  defp attendance_audit_event(:attended), do: "appointment_attended"
  defp attendance_audit_event(:no_show), do: "appointment_no_show"

  defp append_audit!(actor, appointment, event, options) do
    if option(options, :fail_at) == :audit_event do
      Repo.rollback(:audit_unavailable)
    end

    values = [
      audit_actor_kind(actor),
      audit_actor_ref(actor),
      event,
      "appointment:#{appointment.id}"
    ]

    case Ecto.Adapters.SQL.query(Repo, @audit_insert, values) do
      {:ok, _result} -> :ok
      {:error, _reason} -> Repo.rollback(:audit_unavailable)
    end
  end

  defp query_history(%{role: :patient, patient_id: patient_id}) do
    from(a in Appointment,
      where: a.patient_profile_id == ^patient_id,
      order_by: [asc: a.start_time, asc: a.id],
      select: %{
        id: a.id,
        patient_profile_id: a.patient_profile_id,
        professional_account_id: a.professional_account_id,
        consultation_type_id: a.consultation_type_id,
        start_time: a.start_time,
        end_time: a.end_time,
        status: a.status,
        consultation_type_name: a.snapshot_consultation_type_name,
        duration_minutes: a.snapshot_duration_minutes,
        price_ars: a.snapshot_exact_price_ars,
        cancellation_origin: a.cancellation_origin,
        cancellation_reason: a.cancellation_reason
      }
    )
    |> Repo.all()
  end

  defp query_history(%{role: :professional, account_id: account_id}) do
    from(a in Appointment,
      join: patient in Origen.Patients.PatientProfile,
      on: patient.id == a.patient_profile_id,
      left_join: persona in Origen.Patients.Persona,
      on: persona.id == patient.persona_id,
      where: a.professional_account_id == ^account_id,
      order_by: [asc: a.start_time, asc: a.id],
      select: %{
        patient_name:
          fragment(
            "COALESCE(NULLIF(TRIM(CONCAT_WS(' ', ?, ?)), ''), 'Paciente')",
            persona.first_name,
            persona.last_name
          ),
        id: a.id,
        patient_profile_id: a.patient_profile_id,
        professional_account_id: a.professional_account_id,
        consultation_type_id: a.consultation_type_id,
        start_time: a.start_time,
        end_time: a.end_time,
        status: a.status,
        consultation_type_name: a.snapshot_consultation_type_name,
        duration_minutes: a.snapshot_duration_minutes,
        price_ars: a.snapshot_exact_price_ars,
        cancellation_origin: a.cancellation_origin,
        cancellation_reason: a.cancellation_reason
      }
    )
    |> Repo.all()
  end

  defp query_history(%{role: :secretary}) do
    from(a in Appointment,
      join: patient in Origen.Patients.PatientProfile,
      on: patient.id == a.patient_profile_id,
      left_join: persona in Origen.Patients.Persona,
      on: persona.id == patient.persona_id,
      left_join: professional in "professional_profiles",
      on: professional.owner_account_id == a.professional_account_id,
      order_by: [asc: a.start_time, asc: a.id],
      select: %{
        patient_name:
          fragment(
            "COALESCE(NULLIF(TRIM(CONCAT_WS(' ', ?, ?)), ''), 'Paciente no identificado')",
            persona.first_name,
            persona.last_name
          ),
        professional_name:
          fragment(
            "COALESCE(NULLIF(TRIM(CONCAT_WS(' ', ?, ?)), ''), 'Profesional no identificado')",
            professional.first_name,
            professional.last_name
          ),
        id: a.id,
        patient_profile_id: a.patient_profile_id,
        professional_account_id: a.professional_account_id,
        consultation_type_id: a.consultation_type_id,
        start_time: a.start_time,
        end_time: a.end_time,
        status: a.status,
        consultation_type_name: a.snapshot_consultation_type_name,
        duration_minutes: a.snapshot_duration_minutes,
        price_ars: a.snapshot_exact_price_ars,
        cancellation_origin: a.cancellation_origin,
        cancellation_reason: a.cancellation_reason
      }
    )
    |> Repo.all()
  end

  defp resolve_principal(%InternalSession{id: session_id, account_id: account_id}),
    do: resolve_principal(%{session_id: session_id, account_id: account_id})

  defp resolve_principal(%{session_id: session_id, account_id: account_id})
       when is_integer(session_id) and is_integer(account_id) do
    case Sessions.revalidate_principal(session_id, account_id) do
      {:ok, %{account_id: resolved_id, role: role}} when role in [:professional, :secretary] ->
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

  # Maps are cancellation attributes only. Infrastructure controls are accepted
  # exclusively as atom-key keyword options used by trusted callers/tests.
  defp normalize_options(options) when is_list(options) do
    if Enum.all?(options, fn
         {key, _value} when is_atom(key) -> true
         _ -> false
       end),
       do: {:ok, options},
       else: {:error, :invalid_cancellation_options}
  end

  defp normalize_options(options) when is_map(options) do
    {:ok, [reason: Map.get(options, :reason, Map.get(options, "reason"))]}
  end

  defp normalize_options(reason) when is_binary(reason), do: {:ok, [reason: reason]}
  defp normalize_options(nil), do: {:ok, []}
  defp normalize_options(_invalid), do: {:error, :invalid_cancellation_options}

  # This runs after the appointment row has been locked, so the default clock
  # does not precede a concurrent lock wait. Only trusted atom-key options may
  # provide a deterministic test clock.
  defp resolve_now(options) do
    case Keyword.get(options, :now) do
      nil -> {:ok, DateTime.utc_now()}
      %DateTime{} = now -> {:ok, now}
      _ -> {:error, :invalid_cancellation_now}
    end
  end

  defp option(options, key), do: Keyword.get(options, key)
end

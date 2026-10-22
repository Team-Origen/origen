defmodule Origen.Appointments.BookingService do
  @moduledoc """
  Application service for submitting autonomous patient appointment reservations (PLN-09 / Issue #93).
  Enforces:
  - Patient profile completion and phone verification (RF-02 ter, PLN-15)
  - Active Professional account with a complete declared profile (#302), only for autonomous booking
  - Date & slot conversion to UTC DateTime
  - RF-10 initial status resolution based on date proximity
  - Atomic persistence with historical consultation type snapshots via Origen.Booking
  """

  alias Origen.Booking
  alias Origen.Booking.Appointment
  alias Origen.Booking.ProfessionalPatientRelationship
  alias Origen.Patients
  alias Origen.Patients.PatientProfile
  alias Origen.Repo

  @type reservation_params :: %{
          required(:professional_id) => integer() | String.t(),
          required(:consultation_type_id) => String.t(),
          required(:date) => Date.t(),
          required(:slot) => map(),
          optional(:snapshot_override) => map(),
          optional(:now) => DateTime.t()
        }

  @type reservation_result :: %{
          appointment: Appointment.t(),
          appointment_id: integer(),
          status: String.t(),
          consultation_type_name: String.t(),
          duration_minutes: integer(),
          exact_price_ars: Decimal.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t()
        }

  @doc """
  Executes an autonomous appointment reservation for an authenticated patient.

  Returns `{:error, :professional_not_eligible}` without writing a reservation when
  the Professional is inactive or has no complete profile. Revalidates and locks
  eligibility in the persistence transaction; assisted Secretary bookings are unchanged.
  """
  @spec reserve(PatientProfile.t() | nil, reservation_params()) ::
          {:ok, reservation_result()} | {:error, term()}
  def reserve(nil, _params), do: {:error, :unauthenticated}

  def reserve(%PatientProfile{} = profile, params) do
    if Patients.ready_for_booking?(profile) do
      do_reserve(profile, params)
    else
      {:error, :patient_not_ready_for_booking}
    end
  end

  defp do_reserve(profile, params) do
    now = Map.get(params, :now, DateTime.utc_now())
    date = Map.fetch!(params, :date)
    slot = Map.fetch!(params, :slot)

    with {:ok, start_datetime} <- build_start_datetime(date, slot),
         {:ok, prof_id} <- parse_professional_id(Map.fetch!(params, :professional_id)) do
      Repo.transaction(fn ->
        lock_eligible_professional!(prof_id)

        status =
          case Booking.get_approval_configuration(prof_id) do
            {:ok, %{approval_mode: :manual}} ->
              # Contrato #321 §1: la reserva autónoma de un profesional con aprobación
              # manual nace siempre como solicitud, sin importar la proximidad de la fecha.
              "requested"

            _automatic_or_unavailable ->
              determine_initial_status(date, now)
          end

        type_id = Map.fetch!(params, :consultation_type_id)
        snapshot = Map.get(params, :snapshot_override)

        attrs = %{
          patient_profile_id: profile.id,
          professional_account_id: prof_id,
          consultation_type_id: type_id,
          start_time: start_datetime,
          status: status
        }

        case Booking.persist_appointment(attrs, snapshot) do
          {:ok, appointment} ->
            establish_relationship!(appointment)

            %{
              appointment: appointment,
              appointment_id: appointment.id,
              status: appointment.status,
              consultation_type_name: appointment.snapshot_consultation_type_name,
              duration_minutes: appointment.snapshot_duration_minutes,
              exact_price_ars: appointment.snapshot_exact_price_ars,
              start_time: appointment.start_time,
              end_time: appointment.end_time
            }

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)
    end
  end

  defp lock_eligible_professional!(professional_id) do
    # Hold account/profile share locks until persistence completes, so eligibility
    # cannot be revoked between this check and the reservation write.
    case Repo.query(
           """
           SELECT a.id FROM internal_accounts a
           JOIN professional_profiles p ON p.owner_account_id = a.id
           WHERE a.id = $1 AND a.role = 'professional' AND a.state = 'active'
             AND NULLIF(btrim(p.first_name, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.last_name, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.specialty, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.license_type, E' \\t\\n\\r'), '') IS NOT NULL
             AND NULLIF(btrim(p.license_number, E' \\t\\n\\r'), '') IS NOT NULL
           FOR SHARE OF a, p
           """,
           [professional_id]
         ) do
      {:ok, %{rows: [[^professional_id]]}} -> :ok
      {:ok, %{rows: []}} -> Repo.rollback(:professional_not_eligible)
      {:error, _} -> Repo.rollback(:unavailable)
    end
  end

  # RF-05 / OpenSpec `appointment-booking-and-lifecycle`: completar una solicitud o
  # un turno establece la relación Profesional-Paciente durable. Viaja en la misma
  # transacción que la reserva; si ya existe (o otra reserva concurrente la creó),
  # se trata como establecida.
  defp establish_relationship!(%Appointment{} = appointment) do
    %ProfessionalPatientRelationship{}
    |> ProfessionalPatientRelationship.changeset(%{
      professional_account_id: appointment.professional_account_id,
      patient_profile_id: appointment.patient_profile_id,
      first_appointment_id: appointment.id
    })
    |> Repo.insert()
    |> case do
      {:ok, _relationship} ->
        :ok

      {:error, %Ecto.Changeset{} = changeset} ->
        if constraint_violation?(changeset, "professional_patient_relationships_unique_pair") do
          :ok
        else
          Repo.rollback({:relationship_validation_error, changeset})
        end
    end
  end

  defp constraint_violation?(changeset, constraint_name) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
      Keyword.get(opts, :constraint_name) == constraint_name
    end)
  end

  @doc """
  Determines the initial appointment status according to RF-10 rules.
  - Reservations created before D-1 start in 'reserved'.
  - Reservations created on D-1 or day D start in 'confirmed' (automatic approval).
  """
  @spec determine_initial_status(Date.t(), DateTime.t()) :: String.t()
  def determine_initial_status(appointment_date, now) do
    today = DateTime.to_date(now)
    days_ahead = Date.diff(appointment_date, today)

    if days_ahead <= 1 do
      "confirmed"
    else
      "reserved"
    end
  end

  defp build_start_datetime(%Date{} = date, %{start_time: %Time{} = time}) do
    {:ok, DateTime.new!(date, time, "Etc/UTC")}
  end

  defp build_start_datetime(%Date{} = date, %{"start_time" => %Time{} = time}) do
    {:ok, DateTime.new!(date, time, "Etc/UTC")}
  end

  defp build_start_datetime(%Date{} = date, %{start_formatted: formatted}) do
    time_str = if String.length(formatted) == 5, do: formatted <> ":00", else: formatted
    time = Time.from_iso8601!(time_str)
    {:ok, DateTime.new!(date, time, "Etc/UTC")}
  end

  defp build_start_datetime(%Date{} = date, %{"start_formatted" => formatted}) do
    time_str = if String.length(formatted) == 5, do: formatted <> ":00", else: formatted
    time = Time.from_iso8601!(time_str)
    {:ok, DateTime.new!(date, time, "Etc/UTC")}
  end

  defp build_start_datetime(_date, _slot), do: {:error, :invalid_slot_time}

  defp parse_professional_id(id) when is_integer(id), do: {:ok, id}

  defp parse_professional_id("PRO-DEMO-" <> _rest) do
    case Origen.Repo.query("SELECT id FROM internal_accounts WHERE role = 'professional' LIMIT 1") do
      {:ok, %{rows: [[acc_id]]}} -> {:ok, acc_id}
      _ -> {:ok, 1}
    end
  end

  defp parse_professional_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {num, ""} -> {:ok, num}
      _ -> {:error, :invalid_professional_id}
    end
  end

  defp parse_professional_id(_), do: {:error, :invalid_professional_id}
end

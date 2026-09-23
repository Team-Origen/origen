defmodule Origen.TestSupport.BookingFactory do
  @moduledoc """
  Factory functions for creating test data for booking integration tests.
  """

  alias Origen.Repo
  alias Origen.Bookings.Appointment
  alias Origen.Patients.Patient

  @doc """
  Creates a professional internal account for testing via direct DB insert.
  """
  @spec professional() :: {:ok, map()}
  def professional(attrs \\ []) do
    email = Keyword.get(attrs, :email, "prof_#{:rand.uniform(1_000_000)}@test.com")
    role = Keyword.get(attrs, :role, "professional")
    state = Keyword.get(attrs, :state, "active")
    
    # Insert directly with password hash and TOTP for active state
    password_hash = Origen.BootstrapAdmin.Credentials.hash_password("password123")
    totp_secret = :crypto.strong_rand_bytes(20)
    totp_last_period = div(System.os_time(:second), 30)
    activated_at = DateTime.utc_now()
    
    case Repo.query(
           """
           INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, totp_last_period, activated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, email, role, state
           """,
           [email, role, state, password_hash, totp_secret, totp_last_period, activated_at]
         ) do
      {:ok, %{rows: [[id, email, role, state] | _]}} ->
        {:ok, %{id: id, email: email, role: role, state: state}}
      error ->
        error
    end
  end

  @doc """
  Creates a secretary internal account for testing via direct DB insert.
  """
  @spec secretary() :: {:ok, map()}
  def secretary(attrs \\ []) do
    email = Keyword.get(attrs, :email, "sec_#{:rand.uniform(1_000_000)}@test.com")
    role = Keyword.get(attrs, :role, "secretary")
    state = Keyword.get(attrs, :state, "active")
    
    password_hash = Origen.BootstrapAdmin.Credentials.hash_password("password123")
    totp_secret = :crypto.strong_rand_bytes(20)
    totp_last_period = div(System.os_time(:second), 30)
    activated_at = DateTime.utc_now()
    
    case Repo.query(
           """
           INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, totp_last_period, activated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, email, role, state
           """,
           [email, role, state, password_hash, totp_secret, totp_last_period, activated_at]
         ) do
      {:ok, %{rows: [[id, email, role, state] | _]}} ->
        {:ok, %{id: id, email: email, role: role, state: state}}
      error ->
        error
    end
  end

  @doc """
  Creates a patient for testing (PAT-01).
  """
  @spec patient(attrs :: keyword()) :: {:ok, Patient.t()} | {:error, term()}
  def patient(attrs \\ []) do
    defaults = %{
      auth_subject: "google-oauth2|#{:rand.uniform(1_000_000)}",
      auth_provider: :google,
      profile_complete: true,
      phone_verified: true,
      primary_notification_phone: "+54911#{:rand.uniform(10_000_000)}"
    }
    
    attrs = Keyword.merge(defaults, attrs)
    
    changeset = Patient.create_changeset(%Patient{}, attrs)
    Repo.insert(changeset)
  end

  @doc """
  Creates a consultation type for a professional.
  Returns a mock structure that matches the MockCatalog format.
  """
  @spec consultation_type(professional_id :: integer(), attrs :: keyword()) :: {:ok, map()}
  def consultation_type(professional_id, attrs \\ []) do
    id = "018f4a5b-0d62-7a44-8e32-2f608bfcb#{:rand.uniform(100) |> Integer.to_string() |> String.pad_leading(2, "0")}"
    
    {:ok, %{
      id: id,
      professional_id: professional_id,
      name: Keyword.get(attrs, :name, "Consulta general"),
      interval_count: Keyword.get(attrs, :interval_count, 2),
      exact_price_ars: Keyword.get(attrs, :price, Decimal.new("18000.00")),
      color: Keyword.get(attrs, :color, "#0A7C86"),
      status: :active,
      agenda_interval_minutes: 15
    }}
  end

  @doc """
  Creates a valid booking params map.
  """
  @spec booking_params(professional_id :: integer(), patient_id :: integer(), consultation_type_id :: binary(), 
                       starts_at :: DateTime.t(), ends_at :: DateTime.t(), opts :: keyword()) :: map()
  def booking_params(professional_id, patient_id, consultation_type_id, starts_at, ends_at, opts \\ []) do
    %{
      professional_id: professional_id,
      patient_id: patient_id,
      consultation_type_id: consultation_type_id,
      starts_at: starts_at,
      ends_at: ends_at,
      initial_state: Keyword.get(opts, :initial_state, :reservado),
      modality: Keyword.get(opts, :modality, :automatic),
      agreement_declaration: Keyword.get(opts, :agreement_declaration, false),
      is_first_booking: Keyword.get(opts, :is_first_booking, true)
    }
  end

  @doc """
  Creates a patient actor for booking.
  """
  @spec patient_actor(patient :: Patient.t(), professional_reference :: String.t()) :: map()
  def patient_actor(patient, professional_reference) do
    %{
      type: :patient,
      account_id: patient.id,
      patient_id: patient.id,
      profile_complete: patient.profile_complete,
      phone_verified: patient.phone_verified,
      own_profile: true,
      professional_reference: professional_reference
    }
  end

  @doc """
  Creates a secretary actor for booking.
  """
  @spec secretary_actor(secretary :: map(), professional_reference :: String.t()) :: map()
  def secretary_actor(secretary, professional_reference) do
    %{
      type: :secretary,
      account_id: secretary.id,
      center_scope_valid: true,
      minimum_identity_complete: true,
      professional_reference: professional_reference
    }
  end

  @doc """
  Creates a professional actor for booking.
  """
  @spec professional_actor(professional :: map(), allowed_patient_ids :: [integer()]) :: map()
  def professional_actor(professional, allowed_patient_ids) do
    %{
      type: :professional,
      account_id: professional.id,
      allowed_patient_ids: allowed_patient_ids,
      professional_reference: "PRO-DEMO-001"
    }
  end

  @doc """
  Sets up a complete test scenario with professional, patient, and consultation type.
  """
  @spec setup_scenario() :: {:ok, %{professional: map(), patient: Patient.t(), consultation_type: map()}}
  def setup_scenario() do
    with {:ok, professional} <- professional(),
         {:ok, patient} <- patient(),
         {:ok, consultation_type} <- consultation_type(professional.id) do
      {:ok, %{professional: professional, patient: patient, consultation_type: consultation_type}}
    end
  end

  @doc """
  Creates a time slot for tomorrow at 10:00 AM in organization timezone.
  """
  @spec tomorrow_slot(hour :: integer(), duration_minutes :: integer()) :: {DateTime.t(), DateTime.t()}
  def tomorrow_slot(hour \\ 10, duration_minutes \\ 30) do
    # Organization timezone: America/Argentina/Buenos_Aires (UTC-3)
    org_now = DateTime.shift_zone(DateTime.utc_now(), "America/Argentina/Buenos_Aires")
    org_tomorrow = Date.add(DateTime.to_date(org_now), 1)
    
    starts_at = DateTime.from_naive!(
      NaiveDateTime.new(org_tomorrow, Time.new(hour, 0, 0)),
      "America/Argentina/Buenos_Aires"
    )
    
    ends_at = DateTime.add(starts_at, duration_minutes * 60)
    
    {starts_at, ends_at}
  end

  @doc """
  Creates a time slot for D-1 (today in org timezone) at 10:00 AM.
  """
  @spec d1_slot(hour :: integer(), duration_minutes :: integer()) :: {DateTime.t(), DateTime.t()}
  def d1_slot(hour \\ 10, duration_minutes \\ 30) do
    org_now = DateTime.shift_zone(DateTime.utc_now(), "America/Argentina/Buenos_Aires")
    org_today = DateTime.to_date(org_now)
    
    starts_at = DateTime.from_naive!(
      NaiveDateTime.new(org_today, Time.new(hour, 0, 0)),
      "America/Argentina/Buenos_Aires"
    )
    
    ends_at = DateTime.add(starts_at, duration_minutes * 60)
    
    {starts_at, ends_at}
  end

  @doc """
  Creates a time slot for Día D (yesterday in org timezone) - should be denied for patient.
  """
  @spec dia_d_slot(hour :: integer(), duration_minutes :: integer()) :: {DateTime.t(), DateTime.t()}
  def dia_d_slot(hour \\ 10, duration_minutes \\ 30) do
    org_now = DateTime.shift_zone(DateTime.utc_now(), "America/Argentina/Buenos_Aires")
    org_yesterday = Date.add(DateTime.to_date(org_now), -1)
    
    starts_at = DateTime.from_naive!(
      NaiveDateTime.new(org_yesterday, Time.new(hour, 0, 0)),
      "America/Argentina/Buenos_Aires"
    )
    
    ends_at = DateTime.add(starts_at, duration_minutes * 60)
    
    {starts_at, ends_at}
  end
end
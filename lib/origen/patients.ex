defmodule Origen.Patients do
  @moduledoc """
  Core domain context for Personas and Patient Profiles according to RF-01 and RF-02.
  Handles:
  - Patient profile lifecycle (`pending_completion`, `completed`, `pending_secretary_review`).
  - Mandatory identity completion (names, document, birthdate).
  - Business uniqueness by controlled document type and normalized document number.
  - Document collision handling: derivations to Secretary review without automatic linking.
  - Verification boundary enforcement: phone verification is never marked true here.
  - Sanitized audit logging.
  """

  import Ecto.Query
  alias Origen.Audit.{Events, Writer}

  alias Origen.Patients.{
    PatientProfile,
    Persona,
    PhoneVerificationChallenge,
    PhoneVerificationConfig,
    PhoneVerificationEmail
  }

  alias Origen.Repo

  @doc """
  Gets or creates a patient profile for the given authenticated email.
  New profiles start in `pending_completion` state with `phone_verified: false`.
  """
  @spec get_or_create_profile(String.t()) :: {:ok, PatientProfile.t()} | {:error, term()}
  def get_or_create_profile(email) when is_binary(email) do
    clean_email = email |> String.trim() |> String.downcase()

    case Repo.one(from p in PatientProfile, where: p.email == ^clean_email, preload: [:persona]) do
      %PatientProfile{} = profile ->
        {:ok, profile}

      nil ->
        attrs = %{email: clean_email, state: "pending_completion", phone_verified: false}

        %PatientProfile{}
        |> PatientProfile.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, profile} -> {:ok, Repo.preload(profile, :persona)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Completes a patient profile with personal identity details.
  Enforces:
  1. Mandatory fields: first_name, last_name, document_type, document_number, birthdate.
  2. Document normalization and catalog validation (dni, passport, identity_card, other).
  3. Collision detection:
     - If document is unique: creates Persona, links to profile, sets state to `completed`,
       keeps `phone_verified: false`, and audits completion.
     - If document already exists (collision): does NOT duplicate Persona and does NOT
       automatically link to the existing Persona. Derives the profile to Secretary review
       (`pending_secretary_review`), logs collision timestamp/notes, and audits derivation.
  """
  @spec complete_profile(String.t(), map(), keyword()) ::
          {:ok, %{profile: PatientProfile.t(), persona: Persona.t() | nil, outcome: atom()}}
          | {:error, term()}
  def complete_profile(email, attrs, opts \\ [])

  def complete_profile(email, attrs, opts) when is_binary(email) and is_map(attrs) do
    clean_email = email |> String.trim() |> String.downcase()
    now = Keyword.get(opts, :now, DateTime.utc_now())

    persona_changeset = Persona.changeset(%Persona{}, attrs)

    if persona_changeset.valid? do
      doc_type = Ecto.Changeset.get_field(persona_changeset, :document_type)
      doc_number = Ecto.Changeset.get_field(persona_changeset, :document_number)

      Repo.transaction(fn ->
        {:ok, profile} = get_or_create_profile(clean_email)

        existing_persona =
          Repo.one(
            from p in Persona,
              where: p.document_type == ^doc_type and p.document_number == ^doc_number,
              lock: "FOR UPDATE"
          )

        cond do
          existing_persona != nil and profile.persona_id == existing_persona.id ->
            {:ok, updated_persona} =
              existing_persona
              |> Persona.changeset(attrs)
              |> Repo.update()

            {:ok, updated_profile} =
              profile
              |> PatientProfile.changeset(%{
                state: "completed",
                phone: Map.get(attrs, :phone) || Map.get(attrs, "phone") || profile.phone,
                phone_verified: false,
                collision_detected_at: nil,
                collision_notes: nil
              })
              |> Repo.update()

            audit_profile_completed(clean_email)
            %{profile: updated_profile, persona: updated_persona, outcome: :completed}

          existing_persona != nil ->
            notes =
              "Colisión documental detectada para #{doc_type} #{doc_number}. Derivado a Secretaría."

            {:ok, updated_profile} =
              profile
              |> PatientProfile.changeset(%{
                state: "pending_secretary_review",
                collision_detected_at: now,
                collision_notes: notes
              })
              |> Repo.update()

            audit_collision_derived(clean_email)
            %{profile: updated_profile, persona: nil, outcome: :derived_to_secretary}

          true ->
            {:ok, new_persona} = Repo.insert(persona_changeset)

            {:ok, updated_profile} =
              profile
              |> PatientProfile.changeset(%{
                persona_id: new_persona.id,
                state: "completed",
                phone: Map.get(attrs, :phone) || Map.get(attrs, "phone") || profile.phone,
                phone_verified: false,
                collision_detected_at: nil,
                collision_notes: nil
              })
              |> Repo.update()

            audit_profile_completed(clean_email)
            %{profile: updated_profile, persona: new_persona, outcome: :completed}
        end
      end)
    else
      {:error, persona_changeset}
    end
  end

  @doc """
  Checks if a patient profile is ready for autonomous appointment booking.
  Requires both:
  1. Profile state is "completed"
  2. Phone is verified (phone_verified: true)
  Per acceptance criteria of #87, phone verification is not granted here,
  so completed profiles remain unready for booking until #90 is solved.
  """
  @spec ready_for_booking?(PatientProfile.t()) :: boolean()
  def ready_for_booking?(%PatientProfile{state: "completed", phone_verified: true}), do: true
  def ready_for_booking?(_profile), do: false

  defp audit_profile_completed(email) do
    with {:ok, event} <- Events.patient_profile_completed({:patient, email}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  defp audit_collision_derived(email) do
    with {:ok, event} <- Events.document_collision_derived({:patient, email}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  defp audit_phone_challenge_issued(email) do
    with {:ok, event} <- Events.phone_challenge_issued({:patient, email}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  @doc """
  Requests a phone verification challenge for a patient profile.
  Enforces:
  1. Phone format sanitization.
  2. Frequency cooldown of 60 seconds between resends.
  3. Max hourly limit of 5 requests per profile.
  4. Cryptographic code generation, SHA-256 protected storage, and 10-minute expiry.
  5. Atomically marks existing pending challenges as expired.
  6. Dispatches code to patient email via Swoosh local mailbox.
  7. Audits issuance without exposing the code or full phone number.
  """
  @spec request_phone_verification(PatientProfile.t() | String.t(), String.t(), keyword()) ::
          {:ok, %{challenge: PhoneVerificationChallenge.t(), delivery: atom()}}
          | {:error, term()}
  def request_phone_verification(profile_or_email, phone, opts \\ [])

  def request_phone_verification(%PatientProfile{} = profile, phone, opts) do
    do_request_phone_verification(profile, phone, opts)
  end

  def request_phone_verification(email, phone, opts) when is_binary(email) do
    clean_email = email |> String.trim() |> String.downcase()

    case Repo.one(from p in PatientProfile, where: p.email == ^clean_email) do
      %PatientProfile{} = profile -> do_request_phone_verification(profile, phone, opts)
      nil -> {:error, :profile_not_found}
    end
  end

  defp do_request_phone_verification(profile, phone, opts) when is_binary(phone) do
    normalized_phone = String.replace(phone, ~r/[-.\s]/, "")

    if String.length(normalized_phone) < 6 do
      {:error, :invalid_phone}
    else
      now = Keyword.get(opts, :now, DateTime.utc_now())
      check_rate_limits_and_issue(profile, normalized_phone, now, opts)
    end
  end

  defp do_request_phone_verification(_profile, _phone, _opts), do: {:error, :invalid_phone}

  defp check_rate_limits_and_issue(profile, phone, now, opts) do
    cooldown_seconds = PhoneVerificationConfig.resend_cooldown_seconds()
    cooldown_threshold = DateTime.add(now, -cooldown_seconds, :second)

    recent_challenge =
      Repo.one(
        from c in PhoneVerificationChallenge,
          where: c.patient_profile_id == ^profile.id and c.created_at >= ^cooldown_threshold,
          limit: 1
      )

    if recent_challenge do
      {:error, :cooldown_active}
    else
      hourly_seconds = 3600
      hourly_threshold = DateTime.add(now, -hourly_seconds, :second)

      hourly_count =
        Repo.aggregate(
          from(c in PhoneVerificationChallenge,
            where: c.patient_profile_id == ^profile.id and c.created_at >= ^hourly_threshold
          ),
          :count
        )

      if hourly_count >= PhoneVerificationConfig.max_hourly_requests() do
        {:error, :hourly_limit_exceeded}
      else
        issue_and_deliver_challenge(profile, phone, now, opts)
      end
    end
  end

  defp issue_and_deliver_challenge(profile, phone, now, opts) do
    code = Keyword.get(opts, :code, PhoneVerificationConfig.generate_code())
    code_hash = PhoneVerificationConfig.hash_code(code)
    ttl = PhoneVerificationConfig.code_ttl_seconds()
    expires_at = DateTime.add(now, ttl, :second)

    result =
      Repo.transaction(fn ->
        from(c in PhoneVerificationChallenge,
          where: c.patient_profile_id == ^profile.id and c.state == "pending"
        )
        |> Repo.update_all(set: [state: "expired", updated_at: now])

        challenge_attrs = %{
          patient_profile_id: profile.id,
          phone: phone,
          code_hash: code_hash,
          state: "pending",
          attempts_count: 0,
          expires_at: expires_at,
          created_at: now,
          updated_at: now
        }

        case %PhoneVerificationChallenge{}
             |> PhoneVerificationChallenge.changeset(challenge_attrs)
             |> Repo.insert() do
          {:ok, challenge} ->
            if profile.phone != phone do
              profile
              |> Ecto.Changeset.change(%{phone: phone, phone_verified: false})
              |> Repo.update!()
            end

            audit_phone_challenge_issued(profile.email)
            challenge

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    case result do
      {:ok, challenge} ->
        email = PhoneVerificationEmail.challenge_code(profile.email, phone, code)
        delivery_res = Origen.Mailer.deliver(email)

        case delivery_res do
          {:ok, _metadata} ->
            response = %{challenge: challenge, delivery: :delivered}

            response =
              if Keyword.get(opts, :return_code, false),
                do: Map.put(response, :code, code),
                else: response

            {:ok, response}

          {:error, reason} ->
            {:error, {:delivery_failed, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

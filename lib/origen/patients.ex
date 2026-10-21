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

  @doc """
  Searches a Persona by controlled document type and normalized document number on behalf
  of an authenticated Secretary.
  Returns:
  - `{:ok, %{persona: persona, profile: profile}}` when the identity exists, where `profile`
    is the linked `PatientProfile` (may be `nil` when the persona has no profile yet).
  - `{:ok, nil}` when no persona matches the document.
  Every search is audited in `public.audit_events` with the Secretary as actor and a
  sanitized document reference as entity. The document reference is used because a
  persona id does not exist for missed searches.
  """
  @spec search_persona_by_document(String.t(), String.t(), integer()) ::
          {:ok, %{persona: Persona.t(), profile: PatientProfile.t() | nil} | nil}
          | {:error, :unauthorized}
  def search_persona_by_document(document_type, document_number, secretary_account_id)
      when is_binary(document_type) and is_binary(document_number) do
    with :ok <- authorize_secretary(secretary_account_id) do
      doc_num = Persona.normalize_number(document_number)

      persona =
        Repo.one(
          from p in Persona,
            where: p.document_type == ^document_type and p.document_number == ^doc_num
        )

      profile = linked_profile(persona)

      audit_persona_searched(secretary_account_id, document_type, doc_num)

      case persona do
        nil -> {:ok, nil}
        %Persona{} = found -> {:ok, %{persona: found, profile: profile}}
      end
    end
  end

  @doc """
  Registers an absent/non-existent patient from Secretary (Issue #276, OpenSpec health-center-beta-core).
  Enforces:
  1. Server authorization: actor must be an active account with role `secretary`.
     Rejects administrators, professionals, and inactive accounts ({:error, :unauthorized}).
  2. Mandatory fields: first_name, last_name, document_type, document_number, birthdate, and phone.
  3. DNI uniqueness: rejects if the document already exists ({:error, changeset}).
  4. Optional & shared contact email: email is not required; if present, it is stored in contact_email.
     Shared contact emails do not collide.
  5. No automatic personal access account: profile.email remains nil (magic link not enabled).
  6. Phone verification is never required: phone_verified is false.
  7. Audited in append-only log with Secretary as actor.
  8. Atomic transaction: validation or collision failures produce no partial DB state.
  """
  @spec register_absent_patient(map(), integer()) ::
          {:ok, %{persona: Persona.t(), profile: PatientProfile.t(), outcome: :created}}
          | {:error, Ecto.Changeset.t() | :unauthorized}
  def register_absent_patient(attrs, secretary_account_id) when is_map(attrs) do
    with :ok <- authorize_secretary(secretary_account_id) do
      persona_changeset = Persona.assisted_changeset(%Persona{}, attrs)

      if persona_changeset.valid? do
        doc_type = Ecto.Changeset.get_field(persona_changeset, :document_type)
        doc_num = Ecto.Changeset.get_field(persona_changeset, :document_number)

        Repo.transaction(fn ->
          existing_persona =
            Repo.one(
              from p in Persona,
                where: p.document_type == ^doc_type and p.document_number == ^doc_num,
                lock: "FOR UPDATE"
            )

          case existing_persona do
            nil ->
              create_assisted_persona(persona_changeset, attrs, secretary_account_id)

            %Persona{} ->
              changeset =
                persona_changeset
                |> Ecto.Changeset.add_error(:document_number, "ya ha sido registrado")
                |> Map.put(:action, :insert)

              Repo.rollback(changeset)
          end
        end)
      else
        {:error, persona_changeset}
      end
    end
  end

  @doc """
  Compatibility adapter delegating to `register_absent_patient/2`.
  """
  @spec register_or_reuse_assisted_persona(map(), integer()) ::
          {:ok, %{persona: Persona.t(), profile: PatientProfile.t(), outcome: :created}}
          | {:error, Ecto.Changeset.t() | :unauthorized}
  def register_or_reuse_assisted_persona(attrs, secretary_account_id) when is_map(attrs) do
    register_absent_patient(attrs, secretary_account_id)
  end

  defp linked_profile(nil), do: nil

  defp linked_profile(%Persona{} = persona) do
    Repo.one(
      from pf in PatientProfile,
        where: pf.persona_id == ^persona.id,
        order_by: [asc: pf.id],
        limit: 1
    )
  end

  defp create_assisted_persona(persona_changeset, attrs, secretary_account_id) do
    case Repo.insert(persona_changeset) do
      {:ok, persona} ->
        case insert_assisted_profile(persona, persona_changeset, attrs) do
          {:ok, profile} ->
            audit_persona_created(secretary_account_id, persona)
            %{persona: persona, profile: profile, outcome: :created}

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp insert_assisted_profile(%Persona{} = persona, persona_changeset, attrs) do
    phone =
      Ecto.Changeset.get_change(persona_changeset, :phone) ||
        Map.get(attrs, :phone) || Map.get(attrs, "phone")

    contact_email =
      Ecto.Changeset.get_change(persona_changeset, :email) ||
        Map.get(attrs, :email) || Map.get(attrs, "email")

    clean_email =
      case contact_email do
        nil ->
          nil

        "" ->
          nil

        val when is_binary(val) ->
          trimmed = String.trim(val)
          if trimmed == "", do: nil, else: String.downcase(trimmed)
      end

    %PatientProfile{}
    |> PatientProfile.changeset(%{
      persona_id: persona.id,
      contact_email: clean_email,
      email: nil,
      state: "completed",
      phone: phone,
      phone_verified: false
    })
    |> Repo.insert()
  end

  defp authorize_secretary(secretary_account_id) when is_integer(secretary_account_id) do
    case Repo.query("SELECT id, role, state FROM internal_accounts WHERE id = $1", [
           secretary_account_id
         ]) do
      {:ok, %{rows: [[_id, "secretary", "active"]]}} ->
        :ok

      _ ->
        {:error, :unauthorized}
    end
  end

  defp authorize_secretary(_), do: {:error, :unauthorized}

  # The actor reference keeps the plain account id: `Events` sanitization rejects
  # references containing "secret" (and therefore any "secretary:<id>" prefix), and
  # `actor_kind: "secretary"` already carries the role.
  defp secretary_actor(secretary_account_id),
    do: {:secretary, Integer.to_string(secretary_account_id)}

  defp persona_ref(%Persona{} = persona),
    do: "#{persona.document_type}:#{persona.document_number}"

  defp audit_persona_searched(secretary_account_id, document_type, document_number) do
    with {:ok, event} <-
           Events.persona_searched(
             secretary_actor(secretary_account_id),
             "#{document_type}:#{document_number}"
           ),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  defp audit_persona_created(secretary_account_id, %Persona{} = persona) do
    with {:ok, event} <-
           Events.persona_created(secretary_actor(secretary_account_id), persona_ref(persona)),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

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

  defp audit_phone_challenge_consumed(email) do
    with {:ok, event} <- Events.phone_challenge_consumed({:patient, email}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  defp audit_phone_challenge_failed(email) do
    with {:ok, event} <- Events.phone_challenge_failed({:patient, email}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  @doc """
  Verifies a user-supplied code against the active phone verification challenge.
  Enforces:
  1. Corresponds to the same patient account and phone number.
  2. Constant-time hash verification.
  3. Atomic consumption: single-use only, sets state to "consumed".
  4. Marks patient_profile phone_verified: true upon success.
  5. Rejection of expired challenges (state "expired").
  6. Rejection of consumed challenges (reutilization prevention).
  7. Strict attempt limiting: increments attempts_count on mismatch; marks
     "max_attempts_exceeded" upon reaching 3 failed attempts.
  8. Sanitized audit logging of success or failure without leaking secrets.
  """
  @spec verify_phone_code(PatientProfile.t() | String.t(), String.t(), keyword()) ::
          {:ok, %{profile: PatientProfile.t(), challenge: PhoneVerificationChallenge.t()}}
          | {:error, atom()}
  def verify_phone_code(profile_or_email, code, opts \\ [])

  def verify_phone_code(%PatientProfile{} = profile, code, opts) do
    case Repo.get(PatientProfile, profile.id) do
      nil -> {:error, :profile_not_found}
      fresh_profile -> do_verify_phone_code(fresh_profile, code, opts)
    end
  end

  def verify_phone_code(email, code, opts) when is_binary(email) do
    clean_email = email |> String.trim() |> String.downcase()

    case Repo.one(from p in PatientProfile, where: p.email == ^clean_email) do
      %PatientProfile{} = profile -> do_verify_phone_code(profile, code, opts)
      nil -> {:error, :profile_not_found}
    end
  end

  defp do_verify_phone_code(profile, code, opts) when is_binary(code) do
    clean_code = String.trim(code)

    if String.length(clean_code) != PhoneVerificationConfig.code_length() or
         not Regex.match?(~r/^[0-9]+$/, clean_code) do
      {:error, :invalid_code}
    else
      now = Keyword.get(opts, :now, DateTime.utc_now())

      Repo.transaction(fn ->
        case find_challenge_for_verification(profile.id) do
          {:ok, challenge} ->
            validate_and_consume_challenge(profile, challenge, clean_code, now)

          {:error, reason} ->
            {:error, reason}
        end
      end)
      |> case do
        {:ok, {:ok, result}} -> {:ok, result}
        {:ok, {:error, reason}} -> {:error, reason}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp do_verify_phone_code(_profile, _code, _opts), do: {:error, :invalid_code}

  defp find_challenge_for_verification(profile_id) do
    query =
      from c in PhoneVerificationChallenge,
        where: c.patient_profile_id == ^profile_id,
        order_by: [desc: c.id],
        limit: 1,
        lock: "FOR UPDATE"

    case Repo.one(query) do
      nil ->
        {:error, :no_active_challenge}

      %PhoneVerificationChallenge{state: "consumed"} ->
        {:error, :challenge_consumed}

      %PhoneVerificationChallenge{state: "max_attempts_exceeded"} ->
        {:error, :max_attempts_exceeded}

      %PhoneVerificationChallenge{state: "expired"} ->
        {:error, :challenge_expired}

      %PhoneVerificationChallenge{state: "pending"} = challenge ->
        {:ok, challenge}
    end
  end

  defp validate_and_consume_challenge(profile, challenge, code, now) do
    cond do
      challenge.phone != profile.phone ->
        audit_phone_challenge_failed(profile.email)
        {:error, :phone_mismatch}

      DateTime.compare(now, challenge.expires_at) == :gt ->
        challenge
        |> Ecto.Changeset.change(%{state: "expired", updated_at: now})
        |> Repo.update!()

        audit_phone_challenge_failed(profile.email)
        {:error, :challenge_expired}

      challenge.attempts_count >= PhoneVerificationConfig.max_attempts() ->
        challenge
        |> Ecto.Changeset.change(%{state: "max_attempts_exceeded", updated_at: now})
        |> Repo.update!()

        audit_phone_challenge_failed(profile.email)
        {:error, :max_attempts_exceeded}

      PhoneVerificationConfig.verify_code_hash(code, challenge.code_hash) ->
        {:ok, consumed_challenge} =
          challenge
          |> Ecto.Changeset.change(%{state: "consumed", updated_at: now})
          |> Repo.update()

        {:ok, updated_profile} =
          profile
          |> Ecto.Changeset.change(%{phone_verified: true, updated_at: now})
          |> Repo.update()

        audit_phone_challenge_consumed(profile.email)
        {:ok, %{profile: updated_profile, challenge: consumed_challenge}}

      true ->
        new_attempts = challenge.attempts_count + 1
        max_att = PhoneVerificationConfig.max_attempts()

        new_state =
          if new_attempts >= max_att,
            do: "max_attempts_exceeded",
            else: "pending"

        challenge
        |> Ecto.Changeset.change(%{
          attempts_count: new_attempts,
          state: new_state,
          updated_at: now
        })
        |> Repo.update!()

        audit_phone_challenge_failed(profile.email)

        if new_state == "max_attempts_exceeded" do
          {:error, :max_attempts_exceeded}
        else
          {:error, :invalid_code}
        end
    end
  end
end

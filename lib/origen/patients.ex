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
  alias Origen.Patients.{PatientProfile, Persona}
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
end

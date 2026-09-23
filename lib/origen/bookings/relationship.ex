defmodule Origen.Bookings.Relationship do
  @moduledoc """
  Professional-Patient relationship management.

  The relationship is created atomically on the first successful booking
  and reused for subsequent professional bookings of the same patient.
  """

  alias Origen.Repo
  alias Origen.Bookings.Errors

  @doc """
  Ensures a professional-patient relationship exists.

  If it doesn't exist, creates it with the first_booking_id.
  If it exists, returns the existing relationship.

  Returns {:ok, %Relationship{}} | {:error, Errors.t()}
  """
  @spec ensure_relationship(integer(), integer(), integer()) ::
          {:ok, map()} | {:error, Errors.t()}
  def ensure_relationship(professional_id, patient_id, first_booking_id) do
    case find_relationship(professional_id, patient_id) do
      {:ok, relationship} ->
        {:ok, relationship}

      {:error, :not_found} ->
        create_relationship(professional_id, patient_id, first_booking_id)
    end
  end

  @doc """
  Finds an existing professional-patient relationship.
  """
  @spec find_relationship(integer(), integer()) :: {:ok, map()} | {:error, :not_found}
  def find_relationship(professional_id, patient_id) do
    case Repo.query(
           """
           SELECT id, professional_id, patient_id, first_booking_id, created_at
           FROM professional_patient_relationships
           WHERE professional_id = $1 AND patient_id = $2
           """,
           [professional_id, patient_id]
         ) do
      {:ok, %{rows: [[id, pro_id, pat_id, fb_id, created_at] | _]}} ->
        {:ok, %{
          id: id,
          professional_id: pro_id,
          patient_id: pat_id,
          first_booking_id: fb_id,
          created_at: created_at
        }}
      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Creates a new professional-patient relationship.
  """
  @spec create_relationship(integer(), integer(), integer()) ::
          {:ok, map()} | {:error, Errors.t()}
  def create_relationship(professional_id, patient_id, first_booking_id) do
    case Repo.query(
           """
           INSERT INTO professional_patient_relationships
           (professional_id, patient_id, first_booking_id)
           VALUES ($1, $2, $3)
           RETURNING id, professional_id, patient_id, first_booking_id, created_at
           """,
           [professional_id, patient_id, first_booking_id]
         ) do
      {:ok, %{rows: [[id, pro_id, pat_id, fb_id, created_at] | _]}} ->
        {:ok, %{
          id: id,
          professional_id: pro_id,
          patient_id: pat_id,
          first_booking_id: fb_id,
          created_at: created_at
        }}
      _ ->
        {:error, {:transaction_failed, :relationship_creation_failed}}
    end
  end

  @doc """
  Checks if a professional-patient relationship exists.
  """
  @spec relationship_exists?(integer(), integer()) :: boolean()
  def relationship_exists?(professional_id, patient_id) do
    case find_relationship(professional_id, patient_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Gets all patient IDs that have a relationship with a professional.
  """
  @spec get_allowed_patients(integer()) :: {:ok, [integer()]}
  def get_allowed_patients(professional_id) do
    case Repo.query(
           """
           SELECT patient_id FROM professional_patient_relationships
           WHERE professional_id = $1
           """,
           [professional_id]
         ) do
      {:ok, %{rows: rows}} ->
        {:ok, Enum.map(rows, fn [id] -> id end)}
      _ ->
        {:ok, []}
    end
  end

  @doc """
  Gets the relationship for a specific booking (first booking).
  """
  @spec get_by_first_booking(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_by_first_booking(first_booking_id) do
    case Repo.query(
           """
           SELECT id, professional_id, patient_id, first_booking_id, created_at
           FROM professional_patient_relationships
           WHERE first_booking_id = $1
           """,
           [first_booking_id]
         ) do
      {:ok, %{rows: [[id, pro_id, pat_id, fb_id, created_at] | _]}} ->
        {:ok, %{
          id: id,
          professional_id: pro_id,
          patient_id: pat_id,
          first_booking_id: fb_id,
          created_at: created_at
        }}
      _ ->
        {:error, :not_found}
    end
  end
end
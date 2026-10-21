defmodule Origen.ProfessionalProfiles do
  @moduledoc """
  Private, account-owned Professional profiles.

  Every read/write revalidates the internal session. Saves patch declared fields;
  missing fields retain their saved values and blank strings clear a field. Partial
  profiles can be saved; completeness requires all five declared fields, not a photo.
  No image upload or credential verification is performed.
  """

  alias Origen.{Authorization, Repo, Sessions}
  alias Origen.Authorization.{Fact, Request}

  @fields ~w(first_name last_name specialty license_type license_number)a
  @protected [:id, :account_id, :owner_account_id]

  @doc "Returns the authenticated Professional's saved profile, or nil when absent."
  @spec get_own_profile(map()) :: {:ok, map() | nil} | {:error, :unauthorized | :unavailable}
  def get_own_profile(principal) do
    with_owner(principal, :read_own_profile, &fetch_profile/1)
  end

  @doc "Saves a partial patch of the authenticated Professional's declared profile."
  @spec save_own_profile(map(), map()) ::
          {:ok, map()} | {:error, :unauthorized | :unavailable | {:validation, map()}}
  def save_own_profile(principal, attrs) do
    with_owner(principal, :save_own_profile, fn owner_id ->
      with {:ok, patch} <- validate(attrs) do
        # Serialize patches on the profile, including concurrent first saves.
        Repo.query!(
          "INSERT INTO professional_profiles (owner_account_id) VALUES ($1) ON CONFLICT DO NOTHING",
          [owner_id]
        )

        Repo.query!(
          "SELECT id FROM professional_profiles WHERE owner_account_id = $1 FOR UPDATE",
          [owner_id]
        )

        current = fetch_profile(owner_id)
        profile = Map.merge(current, patch)

        Repo.query!(
          """
          INSERT INTO professional_profiles
            (owner_account_id, first_name, last_name, specialty, license_type, license_number)
          VALUES ($1, $2, $3, $4, $5, $6)
          ON CONFLICT (owner_account_id) DO UPDATE SET
            first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name,
            specialty = EXCLUDED.specialty, license_type = EXCLUDED.license_type,
            license_number = EXCLUDED.license_number, updated_at = clock_timestamp()
          """,
          [owner_id | Enum.map(@fields, &Map.fetch!(profile, &1))]
        )

        fetch_profile(owner_id)
      else
        {:error, errors} -> Repo.rollback({:validation, errors})
      end
    end)
  end

  defp with_owner(%{session_id: session_id, account_id: account_id}, operation, fun)
       when is_integer(session_id) and is_integer(account_id) do
    Repo.transaction(fn ->
      with {:ok, %{account_id: owner_id, role: :professional}} <-
             Sessions.revalidate_principal(session_id, account_id),
           {:allow, :own_02} <- authorize(operation) do
        fun.(owner_id)
      else
        _ -> {:error, :unauthorized}
      end
    end)
    |> case do
      {:ok, {:error, :unauthorized}} -> {:error, :unauthorized}
      {:ok, result} -> {:ok, result}
      {:error, {:validation, errors}} -> {:error, {:validation, errors}}
      {:error, _} -> {:error, :unavailable}
    end
  rescue
    _ -> {:error, :unavailable}
  end

  defp with_owner(_, _, _), do: {:error, :unauthorized}

  defp authorize(operation) do
    Request.new(
      operation: Fact.known(operation),
      subject: Fact.known({:role, :professional}),
      account_state: Fact.known(:active),
      target: Fact.known(%{owner_matches_actor: true}),
      scope: Fact.known(%{authenticated: true})
    )
    |> Authorization.decide()
  end

  defp fetch_profile(owner_id) do
    case Repo.query!(
           """
           SELECT first_name, last_name, specialty, license_type, license_number
           FROM professional_profiles WHERE owner_account_id = $1
           """,
           [owner_id]
         ).rows do
      [] ->
        nil

      [values] ->
        @fields
        |> Enum.zip(values)
        |> Map.new()
        |> Map.merge(%{
          owner_account_id: owner_id,
          complete?: Enum.all?(values, &(is_binary(&1) and String.trim(&1) != ""))
        })
    end
  end

  defp validate(attrs) when is_map(attrs) do
    if Enum.any?(
         @protected,
         &(Map.has_key?(attrs, &1) or Map.has_key?(attrs, Atom.to_string(&1)))
       ) do
      {:error, %{base: :protected_fields}}
    else
      Enum.reduce_while(@fields, {:ok, %{}}, fn field, {:ok, patch} ->
        case Map.fetch(attrs, field) do
          :error -> validate_field(field, Map.fetch(attrs, Atom.to_string(field)), patch)
          found -> validate_field(field, found, patch)
        end
      end)
    end
  end

  defp validate(_), do: {:error, %{base: :invalid}}

  defp validate_field(_, :error, patch), do: {:cont, {:ok, patch}}
  defp validate_field(field, {:ok, nil}, patch), do: {:cont, {:ok, Map.put(patch, field, nil)}}

  defp validate_field(field, {:ok, value}, patch) when is_binary(value) do
    value = String.trim(value)
    {:cont, {:ok, Map.put(patch, field, if(value == "", do: nil, else: value))}}
  end

  defp validate_field(field, _, _), do: {:halt, {:error, %{field => :invalid}}}
end

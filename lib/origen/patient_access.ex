defmodule Origen.PatientAccess do
  @moduledoc """
  Core domain context for Patient passwordless authentication via Magic Link.
  Handles:
  - Cryptographically secure single-use token issuance with SHA-256 digests.
  - Automatic invalidation of previously issued unconsumed links.
  - Delivery via Swoosh Mailer.
  - Token consumption with atomic single-use invalidation and expiration check.
  - Opaque, fail-closed non-enumerating responses.
  - Sanitized append-only audit logging without raw tokens or sensitive URLs.
  """

  import Ecto.Query
  alias Origen.Audit.{Events, Writer}
  alias Origen.PatientAccess.{Email, MagicLink}
  alias Origen.Patients.PatientProfile
  alias Origen.Repo

  @development_build Application.compile_env(:origen, :env) == :dev
  @default_ttl_seconds 900
  @email_regex ~r/^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+.[a-zA-Z0-9-.]+$/

  @doc """
  Requests a magic link for patient authentication.
  Fails closed and non-enumerating: always returns `{:ok, :delivered}` to callers
  even if the email is invalid, preventing account enumeration.
  """
  @spec request_magic_link(String.t(), keyword()) :: {:ok, :delivered}
  def request_magic_link(email, opts \\ [])

  def request_magic_link(email, opts) when is_binary(email) do
    issue_magic_link(email, opts, :email)
    {:ok, :delivered}
  rescue
    _ -> {:ok, :delivered}
  end

  def request_magic_link(_invalid, _opts), do: {:ok, :delivered}

  @doc """
  Issues a transient access URL only for the isolated fictional-data evaluation.
  This deliberately does not verify email possession and never contacts the mailer.
  """
  def request_academic_magic_link(email) do
    case academic_origin() do
      {:ok, origin} -> issue_magic_link(email, [origin: origin], :academic)
      :disabled -> {:error, :disabled}
    end
  rescue
    _ -> {:ok, nil}
  end

  @doc "Returns whether the explicit evaluation configuration is valid."
  def academic_display_enabled?, do: match?({:ok, _}, academic_origin())

  defp academic_origin do
    config = Application.get_env(:origen, :academic_patient_access) || []
    origin = Keyword.get(config, :public_origin)

    uri =
      case URI.new(origin || "") do
        {:ok, uri} -> uri
        _ -> %URI{}
      end

    if config[:enabled] == true and config[:isolated_fictional_data_confirmed] == true and
         allowed_origin?(uri, config) and
         is_nil(uri.userinfo) and uri.path in [nil, ""] and is_nil(uri.query) and
         is_nil(uri.fragment) do
      {:ok, origin}
    else
      :disabled
    end
  rescue
    _ -> :disabled
  end

  defp allowed_origin?(%URI{scheme: scheme, host: host}, config) when is_binary(host) do
    public_https = scheme == "https" and public_host?(host)

    local =
      @development_build and config[:local_development] == true and
        scheme in ["http", "https"] and host in ["localhost", "127.0.0.1", "::1"]

    public_https or local
  end

  defp allowed_origin?(_, _), do: false

  defp public_host?(host) do
    host = host |> String.downcase() |> String.trim_trailing(".")

    # A public deployment uses a DNS name, not an IP literal or numeric shorthand.
    host != "localhost" and not String.ends_with?(host, ".localhost") and
      String.contains?(host, ".") and not String.contains?(host, ":") and
      not Regex.match?(~r/^[0-9.]+$/, host)
  end

  defp issue_magic_link(email, opts, delivery) when is_binary(email) do
    clean_email = email |> String.trim() |> String.downcase()

    if Regex.match?(@email_regex, clean_email) and linked_patient_email?(clean_email) do
      now = Keyword.get(opts, :now, DateTime.utc_now())
      ttl = Keyword.get(opts, :ttl_seconds, @default_ttl_seconds)
      expires_at = DateTime.add(now, ttl, :second)

      raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      token_digest = :crypto.hash(:sha256, raw_token)

      Repo.transaction(fn ->
        # 1. Invalidate previous unconsumed links for this email
        from(m in MagicLink, where: m.email == ^clean_email and is_nil(m.consumed_at))
        |> Repo.update_all(set: [consumed_at: now])

        # 2. Insert new magic link
        attrs = %{
          email: clean_email,
          token_digest: token_digest,
          expires_at: expires_at,
          created_at: now
        }

        %MagicLink{}
        |> MagicLink.changeset(attrs)
        |> Repo.insert!()

        # Normal delivery is unchanged; evaluation does not depend on a provider.
        if delivery == :email do
          email_msg = Email.magic_link(clean_email, raw_token, opts)
          mailer = Keyword.get(opts, :mailer, Origen.Mailer)
          mailer.deliver(email_msg)
        end

        # 4. Append audit event (reference only, never token or full URL)
        with {:ok, event} <- Events.magic_link_issued({:anonymous, nil}, clean_email),
             {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
          :ok
        else
          _ -> Repo.rollback(:audit_unavailable)
        end

        if delivery == :academic, do: Email.magic_link_url(raw_token, opts), else: nil
      end)
      |> case do
        {:ok, url} -> {:ok, url}
        {:error, _} -> {:ok, nil}
      end
    else
      {:ok, nil}
    end
  end

  defp issue_magic_link(_invalid, _opts, _delivery), do: {:ok, nil}

  defp linked_patient_email?(email) do
    Repo.exists?(from p in PatientProfile, where: p.email == ^email)
  end

  @doc """
  Invalidates all pending unconsumed magic links for the given email.
  """
  @spec invalidate_pending_links(String.t(), keyword()) :: {integer(), nil}
  def invalidate_pending_links(email, opts \\ [])

  def invalidate_pending_links(email, opts) when is_binary(email) do
    clean_email = email |> String.trim() |> String.downcase()
    now = Keyword.get(opts, :now, DateTime.utc_now())

    from(m in MagicLink, where: m.email == ^clean_email and is_nil(m.consumed_at))
    |> Repo.update_all(set: [consumed_at: now])
  end

  def invalidate_pending_links(_invalid, _opts), do: {0, nil}

  @doc """
  Returns the patient's personal access possession state.

  The persisted access email alone is not proof of possession. A profile is
  `:unlinked` without an access email, `:pending_verification` while it has no
  consumed magic link, and `:verified` after at least one link for that email
  has been consumed.
  """
  @spec access_status(map() | String.t() | nil) ::
          :unlinked | :pending_verification | :verified
  def access_status(%{email: email}), do: access_status(email)

  def access_status(%{"email" => email}), do: access_status(email)

  def access_status(profile_id) when is_integer(profile_id) do
    case Repo.get(PatientProfile, profile_id) do
      %PatientProfile{email: email} -> access_status(email)
      nil -> :unlinked
    end
  end

  def access_status(email) when is_binary(email) do
    clean_email = email |> String.trim() |> String.downcase()

    cond do
      clean_email == "" ->
        :unlinked

      Repo.exists?(
        from m in MagicLink,
          where: m.email == ^clean_email and not is_nil(m.consumed_at)
      ) ->
        :verified

      true ->
        :pending_verification
    end
  end

  def access_status(_profile_or_email), do: :unlinked

  @doc """
  Consumes a magic link token.
  Validates that:
  def consume_magic_link(raw_token, opts \\ [])
  - The token has not been consumed yet (`consumed_at` is nil).
  - The token has not expired (`now < expires_at`).

  On success, marks `consumed_at = now`, logs audit event, and returns `{:ok, %{email: email}}`.
  On failure, fails closed with `{:error, :invalid_or_expired}` and logs audit event.
  """
  @spec consume_magic_link(String.t(), keyword()) ::
          {:ok, %{email: String.t()}} | {:error, :invalid_or_expired}
  def consume_magic_link(raw_token, opts \\ [])

  def consume_magic_link(raw_token, opts)
      when is_binary(raw_token) and byte_size(raw_token) >= 16 do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    token_digest = :crypto.hash(:sha256, raw_token)

    Repo.transaction(fn ->
      query =
        from(m in MagicLink,
          where: m.token_digest == ^token_digest,
          select: m,
          lock: "FOR UPDATE"
        )

      case Repo.one(query) do
        %MagicLink{consumed_at: nil, expires_at: expires_at, email: email} = link ->
          if DateTime.compare(now, expires_at) == :lt do
            # Atomically mark consumed
            {1, _} =
              from(m in MagicLink, where: m.id == ^link.id and is_nil(m.consumed_at))
              |> Repo.update_all(set: [consumed_at: now])

            # Audit consumption success
            audit_consume_success(email)

            %{email: email}
          else
            audit_consume_failure(email)
            Repo.rollback(:invalid_or_expired)
          end

        %MagicLink{email: email} ->
          audit_consume_failure(email)
          Repo.rollback(:invalid_or_expired)

        nil ->
          audit_consume_failure(nil)
          Repo.rollback(:invalid_or_expired)
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, :invalid_or_expired} -> {:error, :invalid_or_expired}
      {:error, _other} -> {:error, :invalid_or_expired}
    end
  end

  def consume_magic_link(_invalid, _opts), do: {:error, :invalid_or_expired}

  defp audit_consume_success(email) do
    with {:ok, event} <- Events.magic_link_consumed({:patient, email}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end

  defp audit_consume_failure(email) do
    with {:ok, event} <- Events.magic_link_failed({:anonymous, nil}, email),
         {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _ -> :ok
    end
  end
end

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
  alias Origen.Repo

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
    clean_email = email |> String.trim() |> String.downcase()

    if Regex.match?(@email_regex, clean_email) do
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

        magic_link =
          %MagicLink{}
          |> MagicLink.changeset(attrs)
          |> Repo.insert!()

        # 3. Deliver email via Swoosh
        email_msg = Email.magic_link(clean_email, raw_token, opts)
        mailer = Keyword.get(opts, :mailer, Origen.Mailer)
        mailer.deliver(email_msg)

        # 4. Append audit event (reference only, never token or full URL)
        with {:ok, event} <- Events.magic_link_issued({:anonymous, nil}, clean_email),
             {:ok, _} <- Writer.append(event, {:allow, :sys_01}) do
          :ok
        else
          _ -> Repo.rollback(:audit_unavailable)
        end

        magic_link
      end)
    end

    {:ok, :delivered}
  rescue
    _ -> {:ok, :delivered}
  end

  def request_magic_link(_invalid, _opts), do: {:ok, :delivered}

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

defmodule Origen.BootstrapAdmin.OperatorInvitation do
  @moduledoc """
  Operator command that creates the first pending Administrator and returns its
  one-time activation link, for an installation without email delivery.

  It is a simplified alternative to the two-person approval flow: the operator
  hands the link to the account holder, who sets a password and enrolls TOTP on
  `/administrador/activar`. The account stays `pending_activation` until then.

  Guarantees:

    * refuses before reading arguments unless `ORIGEN_OPERATOR_INVITATION_ENABLED`
      is exactly `"true"` for this invocation (the web service never sets it);
    * a first issue only succeeds while no Administrator exists;
    * `--account-id` reissues for a still-pending account and revokes its previous
      invitation; an active account is refused;
    * the issuance and the operator handoff are written to the audit log, and the
      invitation is revoked if the handoff cannot be audited.
  """

  alias Origen.Audit.{Events, Writer}
  alias Origen.BootstrapAdmin.{Account, Delivery}

  @enable_var "ORIGEN_OPERATOR_INVITATION_ENABLED"
  @issued_by_ref "operator_cli"
  @switches [host: :string, account_id: :integer]
  @host_pattern ~r/\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,62}\z/
  @activation_path "/administrador/activar"

  @type result :: %{
          account_id: pos_integer(),
          invitation_id: pos_integer(),
          expires_at: DateTime.t(),
          link: String.t()
        }

  @doc """
  Runs the command. `opts` exists for tests: `:env` (defaults to the process
  environment), `:verifier_key` (defaults to the configured activation key) and
  `:audit_handoff` (defaults to writing the handoff audit event).

  When the handoff cannot be audited after the account was created, it returns
  `{:error, :audit_unavailable, %{account_id: id, revoked: boolean}}`: the
  pending account is kept, so the operator retries with `--account-id id`.
  """
  @spec run([String.t()], keyword()) ::
          {:ok, result()}
          | {:error, atom()}
          | {:error, :audit_unavailable, %{account_id: pos_integer(), revoked: boolean()}}
  def run(args, opts \\ []) when is_list(args) do
    env = Keyword.get_lazy(opts, :env, &System.get_env/0)
    key = Keyword.get_lazy(opts, :verifier_key, &configured_verifier_key/0)
    audit = Keyword.get(opts, :audit_handoff, &audit_handoff/1)

    with :ok <- enabled(env),
         {:ok, parsed} <- parse(args),
         :ok <- valid_key(key),
         {:ok, invitation} <- issue(parsed[:account_id], key) do
      hand_off(invitation, parsed.host, audit)
    end
  end

  defp enabled(env) do
    if Map.get(env, @enable_var) == "true",
      do: :ok,
      else: {:error, :operator_invitation_disabled}
  end

  defp parse(args) do
    {options, rest, invalid} = OptionParser.parse(args, strict: @switches)
    parsed = Map.new(options)
    names = for "--" <> name <- args, do: name |> String.split("=", parts: 2) |> hd()

    if rest == [] and invalid == [] and Enum.uniq(names) == names and
         valid_host?(parsed[:host]) and valid_account_id?(parsed[:account_id]) do
      {:ok, parsed}
    else
      {:error, :invalid_arguments}
    end
  end

  defp valid_host?(host) when is_binary(host), do: Regex.match?(@host_pattern, host)
  defp valid_host?(_host), do: false

  defp valid_account_id?(nil), do: true
  defp valid_account_id?(id), do: is_integer(id) and id > 0

  defp valid_key(key) when is_binary(key) and byte_size(key) >= 32, do: :ok
  defp valid_key(_key), do: {:error, :invalid_verifier_key}

  defp issue(nil, key),
    do: Account.issue_first(%{verifier_key: key, issued_by_ref: @issued_by_ref})

  defp issue(account_id, key),
    do: Account.reissue_first(account_id, %{verifier_key: key, issued_by_ref: @issued_by_ref})

  defp hand_off(invitation, host, audit) do
    case audit.(invitation.invitation_id) do
      :ok ->
        {:ok,
         %{
           account_id: invitation.account_id,
           invitation_id: invitation.invitation_id,
           expires_at: invitation.expires_at,
           link: link(host, invitation)
         }}

      {:error, _reason} ->
        # An unaudited handoff is treated like a failed delivery: the link is
        # never printed and its invitation is revoked; the account stays pending.
        revoked =
          match?(
            {:ok, _outcome},
            Delivery.revoke_delivery_failure(invitation.invitation_id, %{
              account_id: invitation.account_id
            })
          )

        {:error, :audit_unavailable, %{account_id: invitation.account_id, revoked: revoked}}
    end
  end

  defp audit_handoff(invitation_id) do
    with {:ok, event} <-
           Events.invitation_delivery_handoff(
             {:provider, @issued_by_ref},
             to_string(invitation_id)
           ),
         {:ok, _row} <- Writer.append(event, {:allow, :sys_01}) do
      :ok
    else
      _failure -> {:error, :audit_unavailable}
    end
  end

  # The token travels only in the fragment, which browsers never send to the
  # server; the activation page posts it and removes it from the address bar.
  defp link(host, %{invitation_id: id, token: token}) do
    fragment = URI.encode_query(%{"invitation_id" => id, "token" => token})
    "https://#{host}#{@activation_path}##{fragment}"
  end

  defp configured_verifier_key, do: Application.get_env(:origen, :bootstrap_admin_verifier_key)
end

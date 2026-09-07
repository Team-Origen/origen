defmodule Mix.Tasks.Origen.BootstrapAdmin do
  @moduledoc """
  Creates the first pending administrator and delivers its invitation.

  The task is intentionally narrow: the shared bootstrap gate is checked before
  options, configuration, or repository state are read.
  """

  use Mix.Task

  import Swoosh.Email

  alias Origen.BootstrapAdmin
  alias Origen.BootstrapAdmin.Gate

  @shortdoc "Create the first administrator invitation"
  @switches [account_id: :integer, email: :string, issued_by_ref: :string]

  @impl Mix.Task
  def run(args) do
    case Gate.check() do
      :ok -> execute(args)
      {:error, :bootstrap_disabled} -> Mix.raise("Bootstrap admin is disabled")
    end
  end

  @doc false
  @spec build_invitation_email(map()) :: Swoosh.Email.t()
  def build_invitation_email(%{
        recipient: recipient,
        account_id: account_id,
        invitation_id: invitation_id
      }) do
    new()
    |> to(recipient)
    |> from(Application.get_env(:origen, :bootstrap_admin_mail_from, "no-reply@localhost"))
    |> subject("Administrator activation invitation")
    |> text_body("""
    Complete administrator activation using the references below.

    Account reference: #{account_id}
    Invitation reference: #{invitation_id}
    """)
  end

  defp execute(args) do
    {options, rest, invalid} = OptionParser.parse(args, strict: @switches)

    if rest == [] and invalid == [] do
      execute_options(options)
    else
      Mix.raise("Bootstrap admin received invalid command-line arguments")
    end
  end

  defp execute_options(options) do
    recipient = options[:email] || System.get_env("ORIGEN_BOOTSTRAP_ADMIN_EMAIL")
    verifier_key = System.get_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY")

    with {:ok, email} <- validate_recipient(recipient),
         {:ok, key} <- validate_verifier_key(verifier_key),
         {:ok, invitation} <-
           issue_invitation(options[:account_id], key, options[:issued_by_ref]),
         {:ok, _delivered} <- deliver_invitation(invitation, email) do
      Mix.shell().info(
        "Bootstrap admin invitation delivered; account reference: #{invitation.account_id}; " <>
          "invitation reference: #{invitation.invitation_id}"
      )
    else
      {:error, :invalid_recipient} ->
        Mix.raise("Bootstrap admin requires a non-blank email")

      {:error, :invalid_verifier_key} ->
        Mix.raise("Bootstrap admin requires a verifier key of at least 32 bytes")

      {:error, {:delivery_error, invitation}} ->
        delivery_failed(invitation)

      {:error, _reason} ->
        Mix.raise("Bootstrap admin request was rejected")
    end
  end

  defp validate_recipient(value) when is_binary(value) do
    if String.trim(value) == "", do: {:error, :invalid_recipient}, else: {:ok, value}
  end

  defp validate_recipient(_value), do: {:error, :invalid_recipient}

  defp validate_verifier_key(value) when is_binary(value) and byte_size(value) >= 32,
    do: {:ok, value}

  defp validate_verifier_key(_value), do: {:error, :invalid_verifier_key}

  defp delivery_failed(invitation) do
    Mix.raise(
      "Bootstrap admin delivery failed; account reference: #{invitation.account_id}; " <>
        "invitation reference: #{invitation.invitation_id}. " <>
        "Retry or reissue with --account-id #{invitation.account_id}"
    )
  end

  defp issue_invitation(nil, key, issued_by_ref),
    do: BootstrapAdmin.issue_first(%{verifier_key: key, issued_by_ref: issued_by_ref})

  defp issue_invitation(account_id, key, issued_by_ref),
    do:
      BootstrapAdmin.reissue_first(account_id, %{
        verifier_key: key,
        issued_by_ref: issued_by_ref
      })

  defp deliver_invitation(invitation, recipient) do
    email =
      invitation
      |> Map.take([:account_id, :invitation_id])
      |> Map.put(:recipient, recipient)
      |> build_invitation_email()

    mailer = Application.get_env(:origen, :bootstrap_admin_mailer) || Origen.Mailer

    case mailer.deliver(email) do
      {:ok, _result} = result -> result
      _failure -> {:error, {:delivery_error, invitation}}
    end
  end
end

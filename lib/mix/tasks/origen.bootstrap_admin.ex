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
  @switches [account_id: :integer, email: :string, verifier_key: :string, issued_by_ref: :string]

  @impl Mix.Task
  def run(args) do
    case Gate.check() do
      :ok -> execute(args)
      {:error, :bootstrap_disabled} -> Mix.shell().error("Bootstrap admin is disabled")
    end
  end

  @doc false
  @spec build_invitation_email(map()) :: Swoosh.Email.t()
  def build_invitation_email(%{
        recipient: recipient,
        account_id: account_id,
        invitation_id: invitation_id,
        token: _token
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
    {options, [], []} = OptionParser.parse(args, strict: @switches)
    recipient = options[:email] || System.get_env("ORIGEN_BOOTSTRAP_ADMIN_EMAIL")
    verifier_key = options[:verifier_key] || System.get_env("ORIGEN_BOOTSTRAP_VERIFIER_KEY")

    with email when is_binary(email) <- recipient,
         key when is_binary(key) <- verifier_key,
         {:ok, invitation} <-
           issue_invitation(options[:account_id], key, options[:issued_by_ref]),
         {:ok, _delivered} <- deliver_invitation(invitation, email) do
      Mix.shell().info(
        "Bootstrap admin invitation delivered; account reference: #{invitation.account_id}; " <>
          "invitation reference: #{invitation.invitation_id}"
      )
    else
      nil -> Mix.shell().error("Bootstrap admin requires an email and verifier key")
      {:error, reason} -> Mix.shell().error("Bootstrap admin failed: #{inspect(reason)}")
    end
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
    invitation
    |> Map.take([:account_id, :invitation_id])
    |> Map.put(:recipient, recipient)
    |> build_invitation_email()
    |> Origen.Mailer.deliver()
  end
end

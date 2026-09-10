defmodule Origen.BootstrapAdmin.InvitationEmail do
  @moduledoc "Builds the transient, fragment-only bootstrap invitation message."

  alias Origen.BootstrapAdmin.{Approval, Origin}
  alias Swoosh.Email

  @message "Activate the approved staging administrator invitation:"
  @subject "Staging administrator invitation"

  @spec build(map(), Approval.t(), Origin.t(), map()) ::
          {:ok, Email.t()} | {:error, :invalid_invitation_email}
  def build(
        %{reference: reference, token: token},
        %Approval{destination: destination},
        %Origin{} = origin,
        %{from: from}
      )
      when is_binary(reference) and reference != "" and is_binary(token) and token != "" and
             is_binary(destination) and destination != "" and is_binary(from) and from != "" do
    link =
      Origin.to_uri(origin) <>
        "#invitation_id=#{encode(reference)}&token=#{encode(token)}"

    email =
      Email.new()
      |> Email.to(destination)
      |> Email.from(from)
      |> Email.subject(@subject)
      |> Email.text_body("#{@message}\n#{link}\n")
      |> Email.html_body(~s(<p>#{@message}</p><p><a href="#{link}">Activate invitation</a></p>))

    {:ok, email}
  end

  def build(_invitation, _approval, _origin, _config),
    do: {:error, :invalid_invitation_email}

  defp encode(value), do: URI.encode(value, &URI.char_unreserved?/1)
end

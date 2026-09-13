defmodule Origen.BootstrapAdmin.Local.InvitationEmail do
  @moduledoc "Builds the transient, fragment-only bootstrap invitation message for local development."

  alias Origen.BootstrapAdmin.Local.{Destination, Origin}
  alias Swoosh.Email

  @message "Activate the local administrator invitation:"
  @subject "Local administrator invitation"

  @spec build(map(), Destination.t(), Origin.t(), map()) ::
          {:ok, Email.t()} | {:error, :invalid_invitation_email}
  def build(
        %{reference: reference, token: token},
        %Destination{address: destination},
        %Origin{} = origin,
        config
      )
      when is_binary(reference) and reference != "" and is_binary(token) and token != "" and
             is_binary(destination) and destination != "" and is_map(config) do
    from = Map.get(config, :from, "bootstrap@example.test")

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

  def build(_invitation, _destination, _origin, _config),
    do: {:error, :invalid_invitation_email}

  defp encode(value), do: URI.encode(value, &URI.char_unreserved?/1)
end

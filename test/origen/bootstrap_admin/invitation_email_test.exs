defmodule Origen.BootstrapAdmin.InvitationEmailTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.{Approval, InvitationEmail, Origin}

  test "builds one text/html message with the exact fragment-only activation link" do
    token = "tok+/=? secret"
    reference = "invitation/42"
    destination = "santiago+bootstrap@example.test"
    from = "security@example.test"

    {:ok, origin} =
      Origin.validate("https://approved-host/admin/activate", %{
        environment: :staging,
        approved_hosts: ["approved-host"]
      })

    assert {:ok, email} =
             InvitationEmail.build(
               %{reference: reference, token: token},
               approval(destination),
               origin,
               %{from: from}
             )

    encoded_link =
      "https://approved-host/admin/activate#invitation_id=invitation%2F42&token=tok%2B%2F%3D%3F%20secret"

    assert email.to == [{"", destination}]
    assert email.from == {"", from}
    assert email.subject == "Staging administrator invitation"

    refute Enum.any?(
             [token, reference, destination, encoded_link],
             &String.contains?(email.subject, &1)
           )

    assert email.text_body ==
             "Activate the approved staging administrator invitation:\n#{encoded_link}\n"

    assert email.html_body ==
             ~s(<p>Activate the approved staging administrator invitation:</p><p><a href="#{encoded_link}">Activate invitation</a></p>)

    server_visible = URI.parse(encoded_link)
    assert server_visible.path == "/admin/activate"
    assert server_visible.query == nil
    refute inspect(Map.take(email, [:headers, :private, :assigns])) =~ token
  end

  test "rejects malformed invitation values with a constant safe error" do
    {:ok, origin} =
      Origin.validate("https://approved-host/admin/activate", %{
        environment: :staging,
        approved_hosts: ["approved-host"]
      })

    for invitation <- [
          %{reference: "", token: "secret"},
          %{reference: "ref", token: ""},
          %{reference: "ref", token: 7}
        ] do
      assert {:error, :invalid_invitation_email} =
               InvitationEmail.build(invitation, approval("address@example.test"), origin, %{
                 from: "from@example.test"
               })
    end
  end

  defp approval(destination) do
    now = DateTime.from_naive!(~N[2026-01-01 00:00:00], "Etc/UTC")

    struct!(Approval,
      approval_id: "approval-1",
      requester_ref: "samuel",
      confirmer_ref: "security-reviewer",
      destination: destination,
      environment: "staging",
      operation: :issue,
      issued_at: now,
      expires_at: DateTime.add(now, 300),
      key_id: "key-1"
    )
  end
end

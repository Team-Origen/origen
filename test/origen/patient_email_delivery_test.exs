defmodule Origen.PatientEmailDeliveryTest do
  use Origen.DataCase

  import ExUnit.CaptureLog
  import Swoosh.TestAssertions
  alias Origen.{PatientAccess, Patients, Repo}

  defmodule Provider do
    def deliver(email) do
      send(self(), {:provider_call, email, Repo.in_transaction?()})

      case Process.get(:patient_delivery_result, :ok) do
        :ok -> {:ok, %{id: "test-message"}}
        :error -> {:error, %{body: email.text_body, api_key: "secret-test-key"}}
        :raise -> raise "secret-test-key #{email.text_body}"
      end
    end
  end

  setup do
    {:ok, _} = Patients.get_or_create_profile("delivery@example.test")
    :ok
  end

  test "uses the configured sender and endpoint origin in both email bodies" do
    previous = Application.get_env(:origen, :patient_access_email)
    Application.put_env(:origen, :patient_access_email, from: "acceso@mail.example.org")
    on_exit(fn -> Application.put_env(:origen, :patient_access_email, previous) end)

    email = PatientAccess.Email.magic_link("delivery@example.test", "test-token")
    assert email.from == {"Origen", "acceso@mail.example.org"}
    expected = OrigenWeb.Endpoint.url() <> "/paciente/acceso/verificar?token=test-token"
    assert email.text_body =~ expected
    assert email.html_body =~ expected
  end

  test "sends only after committing issuance and preserves token consumption" do
    assert {:ok, :delivered} =
             PatientAccess.request_magic_link("delivery@example.test", mailer: Provider)

    assert_receive {:provider_call, email, false}
    [_, token] = Regex.run(~r/token=([^\s]+)/, email.text_body)
    assert {:ok, %{email: "delivery@example.test"}} = PatientAccess.consume_magic_link(token)
    assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link(token)
  end

  test "rejects and raises without leaking provider details or changing the public response" do
    for result <- [:error, :raise] do
      Process.put(:patient_delivery_result, result)

      log =
        capture_log(fn ->
          assert {:ok, :delivered} =
                   PatientAccess.request_magic_link("delivery@example.test", mailer: Provider)
        end)

      assert_receive {:provider_call, email, false}
      assert log =~ "patient_magic_link_delivery_failed"
      refute log =~ "secret-test-key"
      refute log =~ "delivery@example.test"
      refute log =~ email.text_body
      [_, token] = Regex.run(~r/token=([^\s]+)/, email.text_body)
      refute log =~ token
    end
  end

  test "a failed issuance does not send or invalidate the previous usable link" do
    assert {:ok, :delivered} =
             PatientAccess.request_magic_link("delivery@example.test", mailer: Provider)

    assert_receive {:provider_call, email, false}
    [_, token] = Regex.run(~r/token=([^\s]+)/, email.text_body)

    capture_log(fn ->
      assert {:ok, :delivered} =
               PatientAccess.request_magic_link("delivery@example.test",
                 mailer: Provider,
                 origin: {:invalid_origin}
               )
    end)

    refute_receive {:provider_call, _, _}
    assert {:ok, %{email: "delivery@example.test"}} = PatientAccess.consume_magic_link(token)
  end

  test "an explicit trusted origin option still works and network retries are disabled" do
    email =
      PatientAccess.Email.magic_link("delivery@example.test", "test-token",
        origin: "https://origen-demo.onrender.com"
      )

    assert email.text_body =~
             "https://origen-demo.onrender.com/paciente/acceso/verificar?token=test-token"

    assert email.html_body =~
             "https://origen-demo.onrender.com/paciente/acceso/verificar?token=test-token"

    assert email.private[:client_options][:retry] == false
    assert email.private[:client_options][:receive_timeout] == 5_000
  end

  test "unknown patients do not call the provider" do
    assert {:ok, :delivered} =
             PatientAccess.request_magic_link("unknown@example.test", mailer: Provider)

    refute_receive {:provider_call, _, _}
  end

  test "patient and shared mailers remain isolated test adapters" do
    assert {:ok, :delivered} = PatientAccess.request_magic_link("delivery@example.test")
    assert_email_sent(subject: "Tu enlace de acceso a Origen")

    assert Application.fetch_env!(:origen, Origen.PatientAccess.Mailer)[:adapter] ==
             Swoosh.Adapters.Test

    assert Application.fetch_env!(:origen, Origen.Mailer)[:adapter] == Swoosh.Adapters.Test
  end
end

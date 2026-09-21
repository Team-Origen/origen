defmodule Origen.PatientAccessTest do
  use Origen.DataCase

  import Ecto.Query
  import Swoosh.TestAssertions
  alias Origen.PatientAccess
  alias Origen.PatientAccess.MagicLink
  alias Origen.Repo

  @valid_email "paciente_unit@example.test"

  setup do
    Repo.delete_all(MagicLink)
    :ok
  end

  describe "request_magic_link/2" do
    test "delivers single-use email and stores SHA-256 digest without raw token" do
      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)

      assert_email_sent(fn email ->
        assert email.to == [{"", @valid_email}]
        assert email.subject == "Tu enlace de acceso a Origen"
        assert email.html_body =~ "/access/verify?token="

        [_, raw_token] = Regex.run(~r/token=([^"s&]+)/, email.html_body)
        decoded_token = URI.decode_www_form(raw_token)

        # 2. Assert raw token is NOT in database
        refute Repo.get_by(MagicLink, token_digest: decoded_token)

        # 3. Assert digest of raw token IS in database
        expected_digest = :crypto.hash(:sha256, decoded_token)

        link =
          Repo.one(from m in MagicLink, where: m.email == ^@valid_email and is_nil(m.consumed_at))

        assert link != nil
        assert link.token_digest == expected_digest
        assert link.consumed_at == nil
        assert DateTime.compare(link.expires_at, DateTime.utc_now()) == :gt

        true
      end)
    end

    test "invalidates prior unconsumed links when requesting a new one" do
      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)

      link1 =
        Repo.one(from m in MagicLink, where: m.email == ^@valid_email and is_nil(m.consumed_at))

      assert link1 != nil

      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)
      link1_updated = Repo.get!(MagicLink, link1.id)
      assert link1_updated.consumed_at != nil

      active_links =
        Repo.all(from(m in MagicLink, where: m.email == @valid_email and is_nil(m.consumed_at)))

      assert length(active_links) == 1
      assert hd(active_links).id != link1.id
    end

    test "is non-enumerating and returns {:ok, :delivered} for arbitrary inputs" do
      assert {:ok, :delivered} = PatientAccess.request_magic_link("inexistente@example.test")
      assert {:ok, :delivered} = PatientAccess.request_magic_link("formato_invalido")
      assert {:ok, :delivered} = PatientAccess.request_magic_link("")
    end

    test "verifies audit event is created without raw token" do
      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)

      audit_rows =
        Repo.all(
          from(a in "audit_events",
            select: %{
              event: a.event,
              entity_ref: a.entity_ref,
              result: a.result
            }
          )
        )

      assert Enum.any?(audit_rows, fn row ->
               row.event == "magic_link_issued" and row.entity_ref == @valid_email and
                 row.result == "succeeded"
             end)

      # Ensure no raw token or URL in audit log
      for row <- audit_rows do
        refute String.contains?(to_string(row.entity_ref), "token")
        refute String.contains?(to_string(row.entity_ref), "http")
      end
    end
  end

  describe "consume_magic_link/2" do
    test "authenticates patient on valid token and invalidates it immediately" do
      assert {:ok, :delivered} = PatientAccess.request_magic_link(@valid_email)

      raw_token =
        receive do
          {:email, email} ->
            [_, token] = Regex.run(~r/token=([^"s&]+)/, email.html_body)
            URI.decode_www_form(token)
        after
          1000 -> flunk("Expected email to be delivered")
        end

      # First consumption succeeds
      assert {:ok, %{email: @valid_email}} = PatientAccess.consume_magic_link(raw_token)

      # Second consumption fails (single-use)
      assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link(raw_token)
    end

    test "rejects expired tokens" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      digest = :crypto.hash(:sha256, raw_token)

      Repo.insert!(%MagicLink{
        email: @valid_email,
        token_digest: digest,
        expires_at: past,
        consumed_at: nil,
        created_at: past
      })

      assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link(raw_token)
    end

    test "rejects tampered or non-existent tokens" do
      assert {:error, :invalid_or_expired} =
               PatientAccess.consume_magic_link("token_falso_completamente_invalido_1234")

      assert {:error, :invalid_or_expired} = PatientAccess.consume_magic_link("")
    end
  end
end

defmodule Origen.ConsultationTypesTest do
  use Origen.DataCase, async: false

  alias Origen.ConsultationTypes
  alias Origen.Repo
  alias Origen.Sessions

  describe "get_own_configuration/1" do
    test "establishes the default configuration for a persisted professional session" do
      principal = professional_principal!()

      assert {:ok, configuration} = ConsultationTypes.get_own_configuration(principal)
      assert configuration == %{agenda_interval_minutes: 30, consultation_types: []}

      assert {:ok, ^configuration} = ConsultationTypes.get_own_configuration(principal)
    end

    test "returns only consultation types owned by the resolved account" do
      first_account_id = insert_active_account!(:professional)
      second_account_id = insert_active_account!(:professional)
      first_principal = principal_for!(first_account_id)
      second_principal = principal_for!(second_account_id)

      insert_agenda_settings!(first_account_id, 15)
      insert_agenda_settings!(second_account_id, 45)

      insert_consultation_type!(first_account_id,
        id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
        name: "General consultation"
      )

      insert_consultation_type!(second_account_id,
        id: "018f4a5b-0d62-7a44-8e32-2f608bfcb002",
        name: "Private consultation"
      )

      assert {:ok,
              %{
                agenda_interval_minutes: 15,
                consultation_types: [
                  %{
                    id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
                    name: "General consultation",
                    exact_price_ars: price,
                    color: "#0A7C86",
                    interval_count: 2,
                    status: :active,
                    inactive_duration_minutes: nil
                  }
                ]
              }} = ConsultationTypes.get_own_configuration(first_principal)

      assert Decimal.equal?(price, Decimal.new("18000.00"))

      assert {:ok,
              %{
                agenda_interval_minutes: 45,
                consultation_types: [%{name: "Private consultation"}]
              }} = ConsultationTypes.get_own_configuration(second_principal)
    end

    test "reloads account role and state instead of trusting principal claims" do
      professional_id = insert_active_account!(:professional)
      principal = principal_for!(professional_id)

      claimed_role = %{principal | role: :administrator}
      assert {:ok, _configuration} = ConsultationTypes.get_own_configuration(claimed_role)

      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL,
            activated_at = NULL
        WHERE id = $1
        """,
        [professional_id]
      )

      assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)
    end

    test "fails closed for other roles and caller-created or altered account bindings" do
      for role <- [:administrator, :secretary] do
        principal = role |> insert_active_account!() |> principal_for!()
        assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)
      end

      professional_id = insert_active_account!(:professional)
      other_professional_id = insert_active_account!(:professional)
      principal = principal_for!(professional_id)

      assert {:error, :unauthorized} =
               ConsultationTypes.get_own_configuration(%{
                 account_id: professional_id,
                 role: :professional
               })

      assert {:error, :unauthorized} =
               ConsultationTypes.get_own_configuration(%{
                 principal
                 | account_id: other_professional_id,
                   role: :professional
               })

      :ok = Sessions.terminate_all_sessions(professional_id)
      assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)
    end

    test "fails closed for missing accounts and malformed or missing principals" do
      account_id = insert_active_account!(:professional)
      principal = principal_for!(account_id)
      Repo.query!("DELETE FROM internal_accounts WHERE id = $1", [account_id])

      assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)

      for malformed <- [nil, %{}, %{session_id: "1", account_id: 1}, "principal"] do
        assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(malformed)
      end
    end
  end

  defp professional_principal! do
    :professional
    |> insert_active_account!()
    |> principal_for!()
  end

  defp principal_for!(account_id) do
    {:ok, %{session: principal}} = Sessions.create_session(account_id)
    principal
  end

  defp insert_active_account!(role) do
    %{rows: [[account_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    account_id
  end

  defp insert_agenda_settings!(account_id, interval_minutes) do
    Repo.query!(
      """
      INSERT INTO agenda_settings (owner_account_id, interval_minutes)
      VALUES ($1, $2)
      """,
      [account_id, interval_minutes]
    )
  end

  defp insert_consultation_type!(account_id, attrs) do
    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, $4, $5, $6, 'active')
      """,
      [
        attrs |> Keyword.fetch!(:id) |> Ecto.UUID.dump!(),
        account_id,
        Keyword.fetch!(attrs, :name),
        Decimal.new("18000.00"),
        "#0A7C86",
        2
      ]
    )
  end
end

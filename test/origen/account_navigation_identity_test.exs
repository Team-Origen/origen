defmodule Origen.AccountNavigationIdentityTest do
  use Origen.DataCase, async: true

  alias Origen.{Accounts, Repo, Sessions}

  test "secretary identity contains only the revalidated account's email" do
    {first, _, first_email} = principal!(:secretary)
    {second, _, second_email} = principal!(:secretary)

    assert {:ok, %{email: ^first_email}} = Accounts.get_own_navigation_identity(first)
    assert {:ok, %{email: ^second_email}} = Accounts.get_own_navigation_identity(second)
    refute first_email == second_email

    for forged <- [
          %{first | account_id: second.account_id},
          %{second | account_id: first.account_id},
          nil,
          %{}
        ] do
      assert {:error, :unauthenticated} = Accounts.get_own_navigation_identity(forged)
    end

    assert {:ok, %{email: ^first_email}} = Accounts.get_own_navigation_identity(first)
    assert {:ok, %{email: ^second_email}} = Accounts.get_own_navigation_identity(second)
  end

  test "revoked, expired and other-role principals cannot read secretary navigation identity" do
    {secretary, token, _email} = principal!(:secretary)
    Sessions.terminate_session(token)
    assert {:error, :unauthenticated} = Accounts.get_own_navigation_identity(secretary)

    {:ok, %{session: expired}} =
      Sessions.create_session(secretary.account_id,
        now: DateTime.add(DateTime.utc_now(), -3600, :second)
      )

    assert {:error, :unauthenticated} = Accounts.get_own_navigation_identity(expired)

    for role <- [:professional, :administrator] do
      {principal, _, _} = principal!(role)
      assert {:error, :unauthenticated} = Accounts.get_own_navigation_identity(principal)
    end
  end

  defp principal!(role) do
    email = "navigation-#{System.unique_integer([:positive])}@example.test"

    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts (email, role, state, password_hash, totp_secret, activated_at)
        VALUES ($1, $2, 'active', 'hash', decode('0102030405', 'hex'), clock_timestamp())
        RETURNING id
        """,
        [email, Atom.to_string(role)]
      )

    {:ok, %{session: principal, token: token}} = Sessions.create_session(id)
    {principal, token, email}
  end
end

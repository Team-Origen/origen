defmodule Origen.BootstrapAdmin.Local.Authorization do
  @moduledoc false

  alias Origen.Authorization
  alias Origen.Authorization.Fact
  alias Origen.BootstrapAdmin.Local.Readiness
  alias Origen.BootstrapAdmin.Local.Target
  alias Origen.Repo

  @doc """
  Evaluates whether the local bootstrap profile is authorized to issue an administrator invitation.
  Returns `{:ok, ready.destination, target}` on success or `{:error, finding}`.
  """
  def authorize(opts \\ []) do
    readiness_result =
      case Keyword.get(opts, :ready) do
        %Readiness.Ready{} = ready -> {:ok, ready}
        nil -> inspect_canonical_config(opts)
        _ -> {:error, :local_not_ready}
      end

    with {:ok, ready} <- readiness_result,
         {:ok, database_fact} <- assert_isolated_database(ready.database_name),
         target_facts = aggregate_target(),
         {:ok, target_record} <- extract_target(target_facts),
         {:ok, _operation} <- evaluate_operation(target_facts, database_fact) do
      {:ok, ready.destination, Target.new(target_record)}
    end
  end

  defp inspect_canonical_config(opts) do
    config = Keyword.get(opts, :config, Application.get_env(:origen, :bootstrap_admin_local, %{}))

    case Keyword.get(opts, :probes) do
      nil -> Readiness.inspect(config)
      probes -> Readiness.inspect(config, probes)
    end
  end

  defp assert_isolated_database(configured_name) do
    case Repo.config()[:database] do
      ^configured_name when is_binary(configured_name) -> {:ok, :isolated}
      name when is_binary(name) -> {:error, :shared_database}
      _ -> {:error, :database_unverifiable}
    end
  end

  defp aggregate_target do
    import Ecto.Query

    active =
      from(a in "internal_accounts", where: a.role == "administrator" and a.state == "active")
      |> Repo.aggregate(:count)

    pending =
      from(a in "internal_accounts",
        where: a.role == "administrator" and a.state == "pending_activation",
        select: %{id: a.id}
      )
      |> Repo.all()

    invitations =
      from(i in "internal_account_invitations",
        join: a in "internal_accounts",
        on: i.account_id == a.id,
        where: a.role == "administrator" and a.state == "pending_activation",
        select: %{
          account_id: i.account_id,
          consumed_at: i.consumed_at,
          revoked_at: i.revoked_at
        }
      )
      |> Repo.all()

    %{
      active_count: active,
      pending_accounts: pending,
      invitations: invitations
    }
  end

  defp extract_target(%{active_count: 0, pending_accounts: []}), do: {:ok, nil}

  defp extract_target(%{
         active_count: 0,
         pending_accounts: [%{id: id}],
         invitations: invitations
       }) do
    # All existing invitations for this account must be revoked (consumed_at is nil, revoked_at is not nil)
    # or empty (in case no invitation was recorded yet)
    if Enum.all?(invitations, fn inv ->
         inv.account_id == id and is_nil(inv.consumed_at) and not is_nil(inv.revoked_at)
       end) do
      {:ok, %{id: id}}
    else
      {:error, :target_unauthorized}
    end
  end

  defp extract_target(_), do: {:error, :target_unauthorized}

  defp evaluate_operation(target_facts, database_fact) do
    request = build_request(target_facts, database_fact)

    case Authorization.decide(request) do
      {:allow, _rule} ->
        {:known, op} = request.operation
        {:ok, op}

      _ ->
        {:error, :authorization_denied}
    end
  end

  defp build_request(%{active_count: 0, pending_accounts: []}, database_fact) do
    Authorization.Request.new(
      operation: Fact.known(:bootstrap_local_first_administrator),
      subject: Fact.known({:channel, :local_profile}),
      account_state: :not_applicable,
      target: Fact.known(%{administrator_exists: false}),
      scope:
        Fact.known(%{
          profile: :dev,
          readiness: :ready,
          destination: :example_test,
          database: database_fact,
          account: :none
        })
    )
  end

  defp build_request(%{active_count: 0, pending_accounts: [%{id: _}]}, database_fact) do
    Authorization.Request.new(
      operation: Fact.known(:reissue_local_first_administrator),
      subject: Fact.known({:channel, :local_profile}),
      account_state: :not_applicable,
      target: Fact.known(%{role: :administrator, state: :pending_activation}),
      scope:
        Fact.known(%{
          profile: :dev,
          readiness: :ready,
          destination: :example_test,
          database: database_fact,
          active_administrator_exists: false,
          account: :sole_pending
        })
    )
  end

  defp build_request(_, _) do
    Authorization.Request.new(
      operation: Fact.known(:bootstrap_local_first_administrator),
      subject: Fact.known({:channel, :local_profile}),
      account_state: :not_applicable,
      target: Fact.known(%{administrator_exists: true}),
      scope: Fact.known(%{})
    )
  end
end

defmodule Origen.BootstrapAdmin do
  @moduledoc "Transactional first-administrator account and invitation lifecycle."

  alias Origen.BootstrapAdmin.{Account, Invitation}

  defdelegate issue_first(options), to: Account
  defdelegate reissue_first(account_id, options), to: Account
  defdelegate exchange(invitation_id, token, key), to: Invitation
  defdelegate consume(invitation_id, token, key), to: Invitation
  defdelegate activate(invitation_id, token, key, credentials), to: Invitation
  defdelegate activate_bound(invitation_id, account_id, credentials), to: Invitation
end

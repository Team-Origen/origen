defmodule OrigenWeb.Plugs.RequireInternalRoleTest do
  use OrigenWeb.ConnCase, async: true

  alias OrigenWeb.Plugs.RequireInternalRole

  @internal_roles [:administrator, :professional, :secretary]

  test "each canonical internal role is allowed only when explicitly configured", %{conn: conn} do
    for role <- @internal_roles do
      opts = RequireInternalRole.init(roles: role)
      authorized = conn |> assign(:current_role, role) |> RequireInternalRole.call(opts)

      refute authorized.halted
      assert authorized.status == nil
    end
  end

  test "each canonical internal role is denied when omitted from the allowed matrix", %{
    conn: conn
  } do
    for role <- @internal_roles do
      allowed_roles = @internal_roles -- [role]
      opts = RequireInternalRole.init(roles: allowed_roles)
      denied = conn |> assign(:current_role, role) |> RequireInternalRole.call(opts)

      assert denied.halted
      assert denied.status == 403
      assert denied.resp_body == "Forbidden"
    end
  end

  test "professional-only access allows a professional and denies other internal roles", %{
    conn: conn
  } do
    opts = RequireInternalRole.init(roles: [:professional])

    professional =
      conn
      |> assign(:current_role, :professional)
      |> RequireInternalRole.call(opts)

    refute professional.halted

    for role <- [:administrator, :secretary] do
      denied = conn |> assign(:current_role, role) |> RequireInternalRole.call(opts)
      assert denied.halted
      assert denied.status == 403
    end
  end

  test "patient and anonymous identities are always denied", %{conn: conn} do
    opts = RequireInternalRole.init(roles: [:patient])

    for role <- [:patient, nil] do
      denied = conn |> assign(:current_role, role) |> RequireInternalRole.call(opts)
      assert denied.halted
      assert denied.status == 403
    end
  end
end

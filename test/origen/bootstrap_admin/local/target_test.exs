defmodule Origen.BootstrapAdmin.Local.TargetTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Local.Target

  test "new/1 with nil returns nil" do
    assert Target.new(nil) == nil
  end

  test "new/1 with map assigns id, role, and state" do
    target = Target.new(%{id: 42})
    assert target.id == 42
    assert target.role == :administrator
    assert target.state == :pending_activation
  end

  test "Inspect protocol redacts struct contents" do
    target = Target.new(%{id: 42})
    assert inspect(target) == "#Origen.BootstrapAdmin.Local.Target<id: 42>"
  end
end

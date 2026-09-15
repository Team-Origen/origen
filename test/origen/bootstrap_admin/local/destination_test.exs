defmodule Origen.BootstrapAdmin.Local.DestinationTest do
  use ExUnit.Case, async: true

  alias Origen.BootstrapAdmin.Local.Destination

  test "parses one exact lowercase ASCII example.test address into a redacted type" do
    value = "student-1@example.test"

    assert {:ok, destination} = Destination.parse(value)
    assert Destination.address(destination) == value
    refute inspect(destination) =~ value
  end

  test "rejects ambiguous, non-canonical, and unsafe destination values" do
    invalid = [
      "Student@example.test",
      "student@ｅxample.test",
      "student@example.test@example.test",
      "student@example.test.evil",
      "student@example.com",
      "student @example.test",
      "student@example.test\nBcc: canary@example.test",
      "student..one@example.test",
      "student@example.test ",
      ["student@example.test"],
      nil,
      <<255>>
    ]

    for value <- invalid do
      assert Destination.parse(value) == {:error, :invalid_destination}
    end
  end
end

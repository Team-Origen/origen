defmodule Origen.Bookings.SnapshotsTest do
  @moduledoc """
  Tests for Origen.Bookings.Snapshots snapshot capture logic.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.Snapshots

  @valid_type %{
    id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
    reference: "TC-001",
    name: "Consulta general",
    interval_count: 2,
    exact_price_ars: Decimal.new("18000.00"),
    color: "#0A7C86",
    status: :active
  }

  @inactive_type %{@valid_type | status: :inactive}

  describe "capture_snapshot/2" do
    test "captures snapshot for active type with valid duration" do
      assert {:ok, snapshot} = Snapshots.capture_snapshot(@valid_type, 15)
      assert snapshot.name == "Consulta general"
      assert snapshot.duration_minutes == 30  # 2 intervals * 15 minutes
      assert snapshot.price_ars == Decimal.new("18000.00")
    end

    test "rejects inactive type" do
      assert {:error, :inactive_type} = Snapshots.capture_snapshot(@inactive_type, 15)
    end

    test "rejects duration exceeding 240 minutes" do
      type = %{@valid_type | interval_count: 20}  # 20 * 15 = 300 > 240
      assert {:error, :invalid_duration} = Snapshots.capture_snapshot(type, 15)
    end

    test "rejects zero or negative duration" do
      type = %{@valid_type | interval_count: 0}
      assert {:error, :invalid_duration} = Snapshots.capture_snapshot(type, 15)
    end

    test "rejects invalid price (negative)" do
      type = %{@valid_type | exact_price_ars: Decimal.new("-100.00")}
      assert {:error, :invalid_price} = Snapshots.capture_snapshot(type, 15)
    end

    test "rejects invalid price (more than 2 decimals)" do
      type = %{@valid_type | exact_price_ars: Decimal.new("18000.123")}
      assert {:error, :invalid_price} = Snapshots.capture_snapshot(type, 15)
    end

    test "accepts price with 0 decimals" do
      type = %{@valid_type | exact_price_ars: Decimal.new("18000")}
      assert {:ok, snapshot} = Snapshots.capture_snapshot(type, 15)
      assert snapshot.price_ars == Decimal.new("18000")
    end

    test "accepts price with 1 decimal" do
      type = %{@valid_type | exact_price_ars: Decimal.new("18000.5")}
      assert {:ok, snapshot} = Snapshots.capture_snapshot(type, 15)
      assert snapshot.price_ars == Decimal.new("18000.5")
    end

    test "accepts price with 2 decimals" do
      type = %{@valid_type | exact_price_ars: Decimal.new("18000.99")}
      assert {:ok, snapshot} = Snapshots.capture_snapshot(type, 15)
      assert snapshot.price_ars == Decimal.new("18000.99")
    end
  end

  describe "calculate_duration/2" do
    test "calculates duration correctly" do
      assert {:ok, 30} = Snapshots.calculate_duration(2, 15)
      assert {:ok, 60} = Snapshots.calculate_duration(4, 15)
      assert {:ok, 240} = Snapshots.calculate_duration(10, 24)
    end

    test "rejects duration exceeding 240 minutes" do
      assert {:error, :invalid_duration} = Snapshots.calculate_duration(11, 24)
    end

    test "rejects zero duration" do
      assert {:error, :invalid_duration} = Snapshots.calculate_duration(0, 15)
    end
  end

  describe "validate_price/1" do
    test "accepts valid price" do
      assert {:ok, price} = Snapshots.validate_price(Decimal.new("18000.00"))
      assert price == Decimal.new("18000.00")
    end

    test "rejects negative price" do
      assert {:error, :invalid_price} = Snapshots.validate_price(Decimal.new("-100.00"))
    end

    test "rejects non-Decimal input" do
      assert {:error, :invalid_price} = Snapshots.validate_price("18000.00")
      assert {:error, :invalid_price} = Snapshots.validate_price(18000)
      assert {:error, :invalid_price} = Snapshots.validate_price(nil)
    end

    test "rejects more than 2 decimal places" do
      assert {:error, :invalid_price} = Snapshots.validate_price(Decimal.new("18000.123"))
    end
  end
end
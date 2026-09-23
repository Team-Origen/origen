defmodule Origen.Bookings.AvailabilityTest do
  @moduledoc """
  Tests for availability validation and overlap detection.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.Availability
  alias Origen.Bookings.Errors

  @professional_id 1
  @patient_id 1
  @consultation_type_id "018f4a5b-0d62-7a44-8e32-2f608bfcb001"
  @starts_at ~U[2026-01-15 10:00:00Z]
  @ends_at ~U[2026-01-15 10:30:00Z]

  describe "advisory_lock/1" do
    test "acquires advisory lock" do
      assert Availability.advisory_lock(@professional_id) == :ok
    end
  end

  describe "advisory_lock_both/2" do
    test "acquires locks for both professional and patient" do
      assert Availability.advisory_lock_both(@professional_id, @patient_id) == :ok
    end
  end

  # Note: Full integration tests for check_professional_overlap, check_patient_overlap,
  # validate_availability require database setup with consultation_types and professionals tables.
  # These are tested in integration tests.
end
defmodule Origen.Bookings.AppointmentTest do
  @moduledoc """
  Tests for Origen.Bookings.Appointment schema and changesets.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.Appointment

  @valid_attrs %{
    professional_id: 1,
    patient_id: 1,
    consultation_type_id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
    consultation_type_snapshot: %{
      "name" => "Consulta general",
      "duration_minutes" => 30,
      "price_ars" => Decimal.new("18000.00")
    },
    agenda_interval_minutes: 15,
    starts_at: DateTime.utc_now() |> DateTime.add(3600),
    ends_at: DateTime.utc_now() |> DateTime.add(5400),
    state: :solicitado,
    booked_by_actor: :patient,
    booked_by_account_id: 1
  }

  @invalid_attrs %{
    professional_id: nil,
    patient_id: nil,
    consultation_type_id: nil,
    consultation_type_snapshot: nil,
    agenda_interval_minutes: nil,
    starts_at: nil,
    ends_at: nil,
    state: nil,
    booked_by_actor: nil,
    booked_by_account_id: nil
  }

  describe "create_changeset/2" do
    test "validates required fields" do
      changeset = Appointment.create_changeset(%Appointment{}, @invalid_attrs)
      assert not changeset.valid?
      assert [
        :professional_id,
        :patient_id,
        :consultation_type_id,
        :consultation_type_snapshot,
        :agenda_interval_minutes,
        :starts_at,
        :ends_at,
        :state,
        :booked_by_actor,
        :booked_by_account_id
      ] == Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "accepts valid attributes" do
      changeset = Appointment.create_changeset(%Appointment{}, @valid_attrs)
      assert changeset.valid?
    end

    test "validates state enum" do
      changeset = Appointment.create_changeset(%Appointment{}, Map.put(@valid_attrs, :state, :invalid_state))
      assert not changeset.valid?
      assert {:state, "invalid state"} in changeset.errors
    end

    test "validates actor enum" do
      changeset = Appointment.create_changeset(%Appointment{}, Map.put(@valid_attrs, :booked_by_actor, :invalid_actor))
      assert not changeset.valid?
      assert {:booked_by_actor, "invalid actor"} in changeset.errors
    end

    test "validates ends_at after starts_at" do
      attrs = Map.put(@valid_attrs, :ends_at, Map.get(@valid_attrs, :starts_at) |> DateTime.add(-100))
      changeset = Appointment.create_changeset(%Appointment{}, attrs)
      assert not changeset.valid?
      assert {:ends_at, "must be after starts_at"} in changeset.errors
    end

    test "validates snapshot structure" do
      attrs = Map.put(@valid_attrs, :consultation_type_snapshot, %{})
      changeset = Appointment.create_changeset(%Appointment{}, attrs)
      assert not changeset.valid?
      assert {:consultation_type_snapshot, "missing or invalid 'name'"} in changeset.errors
    end

    test "accepts all valid states" do
      Enum.each([:solicitado, :reservado, :confirmado, :asistio, :cancelado, :no_asistio], fn state ->
        changeset = Appointment.create_changeset(%Appointment{}, Map.put(@valid_attrs, :state, state))
        assert changeset.valid?, "State #{state} should be valid"
      end)
    end

    test "accepts all valid actors" do
      Enum.each([:patient, :secretary, :professional], fn actor ->
        changeset = Appointment.create_changeset(%Appointment{}, Map.put(@valid_attrs, :booked_by_actor, actor))
        assert changeset.valid?, "Actor #{actor} should be valid"
      end)
    end
  end

  describe "state_transition_changeset/3" do
    test "allows valid transition from solicitado to reservado" do
      appointment = %Appointment{state: :solicitado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :reservado}, :solicitado)
      assert changeset.valid?
    end

    test "allows valid transition from solicitado to cancelado" do
      appointment = %Appointment{state: :solicitado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :cancelado}, :solicitado)
      assert changeset.valid?
    end

    test "allows valid transition from reservado to confirmado" do
      appointment = %Appointment{state: :reservado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :confirmado}, :reservado)
      assert changeset.valid?
    end

    test "allows valid transition from reservado to cancelado" do
      appointment = %Appointment{state: :reservado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :cancelado}, :reservado)
      assert changeset.valid?
    end

    test "allows valid transition from confirmado to asistio" do
      appointment = %Appointment{state: :confirmado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :asistio}, :confirmado)
      assert changeset.valid?
    end

    test "allows valid transition from confirmado to no_asistio" do
      appointment = %Appointment{state: :confirmado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :no_asistio}, :confirmado)
      assert changeset.valid?
    end

    test "allows valid transition from confirmado to cancelado" do
      appointment = %Appointment{state: :confirmado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :cancelado}, :confirmado)
      assert changeset.valid?
    end

    test "rejects invalid transition from solicitado to confirmado" do
      appointment = %Appointment{state: :solicitado}
      changeset = Appointment.state_transition_changeset(appointment, %{state: :confirmado}, :solicitado)
      assert not changeset.valid?
      assert {:state, "invalid transition from solicitado to confirmado"} in changeset.errors
    end

    test "rejects invalid transition from cancelado to any state" do
      appointment = %Appointment{state: :cancelado}
      Enum.each([:solicitado, :reservado, :confirmado, :asistio, :no_asistio], fn to_state ->
        changeset = Appointment.state_transition_changeset(appointment, %{state: to_state}, :cancelado)
        assert not changeset.valid?, "Transition from cancelado to #{to_state} should be invalid"
      end)
    end

    test "rejects invalid transition from asistio to any state" do
      appointment = %Appointment{state: :asistio}
      Enum.each([:solicitado, :reservado, :confirmado, :cancelado, :no_asistio], fn to_state ->
        changeset = Appointment.state_transition_changeset(appointment, %{state: to_state}, :asistio)
        assert not changeset.valid?, "Transition from asistio to #{to_state} should be invalid"
      end)
    end
  end

  describe "current_state/1" do
    test "returns state as atom" do
      appointment = %Appointment{state: :solicitado}
      assert Appointment.current_state(appointment) == :solicitado
    end
  end

  describe "terminal?/1" do
    test "returns true for terminal states" do
      Enum.each([:asistio, :no_asistio, :cancelado], fn state ->
        appointment = %Appointment{state: state}
        assert Appointment.terminal?(appointment), "State #{state} should be terminal"
      end)
    end

    test "returns false for non-terminal states" do
      Enum.each([:solicitado, :reservado, :confirmado], fn state ->
        appointment = %Appointment{state: state}
        assert not Appointment.terminal?(appointment), "State #{state} should not be terminal"
      end)
    end
  end

  describe "active?/1" do
    test "returns true for active states" do
      Enum.each([:solicitado, :reservado, :confirmado], fn state ->
        appointment = %Appointment{state: state}
        assert Appointment.active?(appointment), "State #{state} should be active"
      end)
    end

    test "returns false for terminal states" do
      Enum.each([:asistio, :no_asistio, :cancelado], fn state ->
        appointment = %Appointment{state: state}
        assert not Appointment.active?(appointment), "State #{state} should not be active"
      end)
    end
  end

  describe "duration_minutes/1" do
    test "calculates duration in minutes" do
      starts_at = ~U[2026-01-15 10:00:00Z]
      ends_at = ~U[2026-01-15 10:30:00Z]
      appointment = %Appointment{starts_at: starts_at, ends_at: ends_at}
      assert Appointment.duration_minutes(appointment) == 30
    end
  end
end
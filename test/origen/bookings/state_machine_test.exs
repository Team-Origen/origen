defmodule Origen.Bookings.StateMachineTest do
  @moduledoc """
  Tests for Origen.Bookings.StateMachine state transitions.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.StateMachine

  describe "valid_transitions/0" do
    test "returns all valid transitions" do
      transitions = StateMachine.valid_transitions()
      
      assert transitions[:solicitado] == [:reservado, :cancelado]
      assert transitions[:reservado] == [:confirmado, :cancelado]
      assert transitions[:confirmado] == [:asistio, :no_asistio, :cancelado]
      assert transitions[:asistio] == []
      assert transitions[:no_asistio] == []
      assert transitions[:cancelado] == []
    end
  end

  describe "can_transition?/2" do
    test "allows valid transitions" do
      assert StateMachine.can_transition?(:solicitado, :reservado)
      assert StateMachine.can_transition?(:solicitado, :cancelado)
      assert StateMachine.can_transition?(:reservado, :confirmado)
      assert StateMachine.can_transition?(:reservado, :cancelado)
      assert StateMachine.can_transition?(:confirmado, :asistio)
      assert StateMachine.can_transition?(:confirmado, :no_asistio)
      assert StateMachine.can_transition?(:confirmado, :cancelado)
    end

    test "rejects invalid transitions" do
      refute StateMachine.can_transition?(:solicitado, :confirmado)
      refute StateMachine.can_transition?(:solicitado, :asistio)
      refute StateMachine.can_transition?(:solicitado, :no_asistio)
      refute StateMachine.can_transition?(:reservado, :solicitado)
      refute StateMachine.can_transition?(:reservado, :asistio)
      refute StateMachine.can_transition?(:reservado, :no_asistio)
      refute StateMachine.can_transition?(:confirmado, :solicitado)
      refute StateMachine.can_transition?(:confirmado, :reservado)
      refute StateMachine.can_transition?(:asistio, :solicitado)
      refute StateMachine.can_transition?(:asistio, :reservado)
      refute StateMachine.can_transition?(:asistio, :confirmado)
      refute StateMachine.can_transition?(:asistio, :cancelado)
      refute StateMachine.can_transition?(:no_asistio, :solicitado)
      refute StateMachine.can_transition?(:no_asistio, :reservado)
      refute StateMachine.can_transition?(:no_asistio, :confirmado)
      refute StateMachine.can_transition?(:no_asistio, :cancelado)
      refute StateMachine.can_transition?(:cancelado, :solicitado)
      refute StateMachine.can_transition?(:cancelado, :reservado)
      refute StateMachine.can_transition?(:cancelado, :confirmado)
      refute StateMachine.can_transition?(:cancelado, :asistio)
      refute StateMachine.can_transition?(:cancelado, :no_asistio)
    end

    test "rejects self-transitions" do
      Enum.each([:solicitado, :reservado, :confirmado, :asistio, :no_asistio, :cancelado], fn state ->
        refute StateMachine.can_transition?(state, state)
      end)
    end
  end

  describe "transition/2" do
    test "returns {:ok, new_state} for valid transitions" do
      assert StateMachine.transition(:solicitado, :reservado) == {:ok, :reservado}
      assert StateMachine.transition(:solicitado, :cancelado) == {:ok, :cancelado}
      assert StateMachine.transition(:reservado, :confirmado) == {:ok, :confirmado}
      assert StateMachine.transition(:reservado, :cancelado) == {:ok, :cancelado}
      assert StateMachine.transition(:confirmado, :asistio) == {:ok, :asistio}
      assert StateMachine.transition(:confirmado, :no_asistio) == {:ok, :no_asistio}
      assert StateMachine.transition(:confirmado, :cancelado) == {:ok, :cancelado}
    end

    test "returns {:error, :invalid_transition} for invalid transitions" do
      assert StateMachine.transition(:solicitado, :confirmado) == {:error, :invalid_transition}
      assert StateMachine.transition(:cancelado, :solicitado) == {:error, :invalid_transition}
    end
  end

  describe "next_states/1" do
    test "returns valid next states" do
      assert StateMachine.next_states(:solicitado) == [:reservado, :cancelado]
      assert StateMachine.next_states(:reservado) == [:confirmado, :cancelado]
      assert StateMachine.next_states(:confirmado) == [:asistio, :no_asistio, :cancelado]
      assert StateMachine.next_states(:asistio) == []
      assert StateMachine.next_states(:no_asistio) == []
      assert StateMachine.next_states(:cancelado) == []
    end
  end

  describe "terminal?/1" do
    test "returns true for terminal states" do
      assert StateMachine.terminal?(:asistio)
      assert StateMachine.terminal?(:no_asistio)
      assert StateMachine.terminal?(:cancelado)
    end

    test "returns false for non-terminal states" do
      refute StateMachine.terminal?(:solicitado)
      refute StateMachine.terminal?(:reservado)
      refute StateMachine.terminal?(:confirmado)
    end
  end

  describe "valid_state?/1" do
    test "returns true for valid states" do
      Enum.each([:solicitado, :reservado, :confirmado, :asistio, :cancelado, :no_asistio], fn state ->
        assert StateMachine.valid_state?(state)
      end)
    end

    test "returns false for invalid states" do
      refute StateMachine.valid_state?(:invalid)
      refute StateMachine.valid_state?(:pending)
    end
  end

  describe "can_cancel?/1" do
    test "returns true for cancellable states" do
      assert StateMachine.can_cancel?(:solicitado)
      assert StateMachine.can_cancel?(:reservado)
      assert StateMachine.can_cancel?(:confirmado)
    end

    test "returns false for non-cancellable states" do
      refute StateMachine.can_cancel?(:asistio)
      refute StateMachine.can_cancel?(:no_asistio)
      refute StateMachine.can_cancel?(:cancelado)
    end
  end

  describe "can_confirm?/1" do
    test "returns true only for reservado" do
      assert StateMachine.can_confirm?(:reservado)
      refute StateMachine.can_confirm?(:solicitado)
      refute StateMachine.can_confirm?(:confirmado)
    end
  end

  describe "can_mark_attended?/1 and can_mark_no_show?/1" do
    test "returns true only for confirmado" do
      assert StateMachine.can_mark_attended?(:confirmado)
      assert StateMachine.can_mark_no_show?(:confirmado)
      Enum.each([:solicitado, :reservado, :asistio, :no_asistio, :cancelado], fn state ->
        refute StateMachine.can_mark_attended?(state)
        refute StateMachine.can_mark_no_show?(state)
      end)
    end
  end

  describe "can_approve?/1" do
    test "returns true only for solicitado" do
      assert StateMachine.can_approve?(:solicitado)
      Enum.each([:reservado, :confirmado, :asistio, :no_asistio, :cancelado], fn state ->
        refute StateMachine.can_approve?(state)
      end)
    end
  end

  describe "describe_state/1" do
    test "returns description for each state" do
      assert StateMachine.describe_state(:solicitado) == "Solicitado - Waiting for professional approval"
      assert StateMachine.describe_state(:reservado) == "Reservado - Approved, pending confirmation"
      assert StateMachine.describe_state(:confirmado) == "Confirmado - Attendance confirmed"
      assert StateMachine.describe_state(:asistio) == "Asistió - Appointment completed"
      assert StateMachine.describe_state(:cancelado) == "Cancelado - Cancelled"
      assert StateMachine.describe_state(:no_asistio) == "No asistió - Patient did not attend"
    end
  end
end
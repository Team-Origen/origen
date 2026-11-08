defmodule Origen.Booking.HistoryTest do
  use Origen.DataCase, async: false

  alias Origen.Booking
  alias Origen.Sessions
  alias Origen.TestSupport.AppointmentLifecycleFixtures, as: Fixtures

  setup do
    %{fixture: Fixtures.create!()}
  end

  test "history is SQL-scoped by revalidated actor and includes expired and cancelled", %{
    fixture: f
  } do
    own = Fixtures.appointment!(f, start_time: ~U[2026-12-02 09:00:00Z], status: "expired")

    cancelled =
      Fixtures.appointment!(f, start_time: ~U[2026-12-02 10:00:00Z], status: "cancelled")

    foreign_agenda =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        start_time: ~U[2026-12-02 11:00:00Z],
        status: "confirmed"
      )

    assert {:ok, patient_history} =
             Booking.list_appointment_history(Fixtures.patient_principal(f))

    assert Enum.map(patient_history, & &1.id) |> Enum.sort() ==
             [own.id, cancelled.id, foreign_agenda.id] |> Enum.sort()

    assert {:ok, professional_history} =
             Booking.list_appointment_history(Fixtures.professional_principal(f))

    assert Enum.map(professional_history, & &1.id) |> Enum.sort() ==
             [own.id, cancelled.id] |> Enum.sort()

    assert {:ok, secretary_history} =
             Booking.list_appointment_history(Fixtures.secretary_principal(f))

    assert Enum.map(secretary_history, & &1.id) |> Enum.sort() ==
             [own.id, cancelled.id, foreign_agenda.id] |> Enum.sort()
  end

  test "tampered internal principal, revoked session, and administrator are denied", %{fixture: f} do
    other = Fixtures.professional_principal(f)

    assert {:error, :unauthorized} =
             Booking.list_appointment_history(%{
               session_id: other.session_id,
               account_id: f.other_professional_id
             })

    revoked = Fixtures.professional_principal(f)
    :ok = Sessions.terminate_session(revoked.token)

    assert {:error, :unauthorized} = Booking.list_appointment_history(revoked)
    assert {:error, :unauthorized} = Booking.list_appointment_history(Fixtures.admin_principal(f))
  end

  test "professional history does not reveal shared patient's other agenda", %{fixture: f} do
    own = Fixtures.appointment!(f, start_time: ~U[2026-12-02 12:00:00Z], status: "confirmed")

    other =
      Fixtures.appointment!(f,
        professional_account_id: f.other_professional_id,
        start_time: ~U[2026-12-02 13:00:00Z],
        status: "confirmed"
      )

    assert {:ok, history} = Booking.list_appointment_history(Fixtures.professional_principal(f))
    assert Enum.map(history, & &1.id) == [own.id]
    refute Enum.any?(history, &(&1.id == other.id))
  end
end

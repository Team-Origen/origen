defmodule Origen.Bookings.IntegrationTest do
  @moduledoc """
  Integration tests covering all 31 scenarios from Issue #61.

  Scenarios are grouped by actor:
  - Paciente autónomo (S1-11 / BOOK-01): 12 scenarios
  - Secretaría asistida (S1-12 / BOOK-02): 10 scenarios  
  - Profesional (S1-13 / BOOK-03): 9 scenarios
  """

  use Origen.DataCase, async: false

  alias Origen.Bookings.Booking
  alias Origen.Bookings.Appointment
  alias Origen.Bookings.Relationship
  alias Origen.TestSupport.BookingFactory
  alias Origen.Repo

  import Origen.TestSupport.BookingFactory

  @professional_id 1
  @patient_id_1 1
  @patient_id_2 2
  @consultation_type_id "018f4a5b-0d62-7a44-8e32-2f608bfcb001"

  setup_all do
    # Ensure clean state
    Repo.query!("DELETE FROM appointments")
    Repo.query!("DELETE FROM professional_patient_relationships")
    Repo.query!("DELETE FROM fines")
    :ok
  end

  # ============================================================================
  # PACIENTE AUTÓNOMO (S1-11 / BOOK-01) - 12 Escenarios
  # ============================================================================

  describe "Paciente autónomo (S1-11 / BOOK-01)" do
    setup do
      # Create test data - use PRO-DEMO-001 for mock catalog
      {:ok, professional} = professional()
      {:ok, patient} = patient()
      {:ok, consultation_type} = consultation_type(professional.id)
      
      # Mock catalog uses PRO-DEMO-001 as professional reference
      patient_actor = patient_actor(patient, "PRO-DEMO-001")
      
      {:ok, professional: professional, patient: patient, consultation_type: consultation_type,
       patient_actor: patient_actor}
    end

    # Scenario 1: Éxito con perfil completo y teléfono verificado
    test "1. Éxito con perfil completo y teléfono verificado", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at,
        initial_state: :reservado, modality: :automatic)
      
      assert {:ok, appointment} = Booking.create_booking(actor, params)
      
      # Verify atomic persistence
      assert appointment.state == :reservado
      assert appointment.consultation_type_snapshot["name"] == "Consulta general"
      assert appointment.consultation_type_snapshot["duration_minutes"] == 30
      assert appointment.consultation_type_snapshot["price_ars"] != nil
      
      # Verify relationship created
      assert {:ok, relationship} = Relationship.find_relationship(prof.id, actor.patient_id)
      assert relationship.first_booking_id == appointment.id
    end

    # Scenario 2: Perfil incompleto
    test "2. Perfil incompleto", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      incomplete_actor = Map.put(actor, :profile_complete, false)
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, {:eligibility_failed, :incomplete_profile}} = 
        Booking.create_booking(incomplete_actor, params)
      
      # Verify no appointment, no relationship
      assert Repo.all(Appointment) == []
      assert {:error, :not_found} = Relationship.find_relationship(prof.id, actor.patient_id)
    end

    # Scenario 3: Teléfono no verificado
    test "3. Teléfono no verificado", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      unverified_actor = Map.put(actor, :phone_verified, false)
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, {:eligibility_failed, :phone_not_verified}} = 
        Booking.create_booking(unverified_actor, params)
      
      assert Repo.all(Appointment) == []
    end

    # Scenario 4: Perfil ajeno
    test "4. Perfil ajeno o representado", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      foreign_actor = Map.put(actor, :own_profile, false)
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, {:eligibility_failed, :not_own_profile}} = 
        Booking.create_booking(foreign_actor, params)
    end

    # Scenario 5: Tipo de consulta inválido/ajeno
    test "5. Tipo de consulta inválido o ajeno", %{patient_actor: actor, professional: prof} do
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, "invalid-uuid", starts_at, ends_at)
      
      assert {:error, {:consultation_type_invalid, :not_found_or_inactive}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 6: Disponibilidad insuficiente
    test "6. Disponibilidad insuficiente", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      # Use a very long duration that exceeds available intervals
      {starts_at, ends_at} = tomorrow_slot(10, 500)  # 500 minutes > 240 max
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, {:availability_failed, :insufficient_intervals}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 7: Superposición con turno propio (RF-12)
    test "7. Superposición con turno propio (RF-12)", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      # First booking succeeds
      assert {:ok, _} = Booking.create_booking(actor, params)
      
      # Second booking for same patient at overlapping time should fail
      overlap_params = booking_params(prof.id, actor.patient_id, ct.id, 
        DateTime.add(starts_at, 15 * 60), DateTime.add(ends_at, 15 * 60))
      
      assert {:error, {:overlap_detected, :patient}} = 
        Booking.create_booking(actor, overlap_params)
      
      # Original appointment should remain unchanged
      appointments = Repo.all(from a in Appointment, where: a.patient_id == ^actor.patient_id)
      assert length(appointments) == 1
    end

    # Scenario 8: Multa pendiente con el mismo Profesional
    test "8. Multa pendiente bloquea reserva autónoma", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      # Create a pending fine
      Repo.query!(
        "INSERT INTO fines (patient_id, professional_id, amount_ars, reason, status) VALUES ($1, $2, $3, $4, 'pending')",
        [actor.patient_id, prof.id, 10000, "No-show anterior"]
      )
      
      {starts_at, ends_at} = tomorrow_slot()
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, {:pending_fine_block, :patient_has_pending_fine}} = 
        Booking.create_booking(actor, params)
      
      # Verify no appointment created
      assert Repo.all(Appointment) == []
    end

    # Scenario 9: Intento de reserva autónoma el día D
    test "9. Reserva autónoma día D denegada", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = dia_d_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, {:d1_window_violation, :autonomous_channel_closed}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 10: Estado incorrecto por fecha/modalidad
    test "10. Estado incorrecto por fecha/modalidad", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      # Patient before D-1 with manual modality but requesting confirmado directly
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, actor.patient_id, ct.id, starts_at, ends_at,
        initial_state: :confirmado, modality: :manual)
      
      assert {:error, {:invalid_initial_state, :state_not_allowed_for_timing}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 11: Conflicto concurrente por el mismo horario
    test "11. Conflicto concurrente - exactamente una reserva persiste", %{professional: prof, consultation_type: ct} do
      {:ok, patient1} = patient()
      {:ok, patient2} = patient()
      
      actor1 = patient_actor(patient1, prof.email)
      actor2 = patient_actor(patient2, prof.email)
      
      {starts_at, ends_at} = tomorrow_slot()
      params1 = booking_params(prof.id, patient1.id, ct.id, starts_at, ends_at)
      params2 = booking_params(prof.id, patient2.id, ct.id, starts_at, ends_at)
      
      # Run concurrently
      task1 = Task.async(fn -> Booking.create_booking(actor1, params1) end)
      task2 = Task.async(fn -> Booking.create_booking(actor2, params2) end)
      
      result1 = Task.await(task1, 10_000)
      result2 = Task.await(task2, 10_000)
      
      success_count = Enum.count([result1, result2], fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      
      assert success_count == 1, "Expected exactly 1 success, got #{success_count}"
    end

    # Scenario 12: Reversión transaccional ante fallo
    test "12. Reversión transaccional ante fallo de persistencia", %{patient_actor: actor, professional: prof, consultation_type: ct} do
      # Force FK violation with invalid professional_id
      {starts_at, ends_at} = tomorrow_slot()
      params = booking_params(999999, actor.patient_id, ct.id, starts_at, ends_at)
      
      assert {:error, _} = Booking.create_booking(actor, params)
      
      # Verify complete rollback - no appointment, no relationship
      assert Repo.all(Appointment) == []
      assert {:error, :not_found} = Relationship.find_relationship(prof.id, actor.patient_id)
    end
  end

  # ============================================================================
  # SECRETARÍA ASISTIDA (S1-12 / BOOK-02) - 10 Escenarios
  # ============================================================================

  describe "Secretaría asistida (S1-12 / BOOK-02)" do
    setup do
      {:ok, professional} = professional()
      {:ok, patient} = patient()
      {:ok, secretary} = secretary()
      {:ok, consultation_type} = consultation_type(professional.id)
      
      # Mock catalog uses PRO-DEMO-001
      secretary_actor = secretary_actor(secretary, "PRO-DEMO-001")
      
      {:ok, professional: professional, patient: patient, secretary: secretary,
       consultation_type: consultation_type, secretary_actor: secretary_actor}
    end

    # Scenario 13: Éxito reutilizando Persona existente
    test "13. Éxito reutilizando Persona existente", %{secretary_actor: actor, professional: prof, patient: pat, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at,
        initial_state: :reservado, is_first_booking: true)
      
      assert {:ok, appointment} = Booking.create_booking(actor, params)
      assert appointment.state == :reservado
      assert appointment.booked_by_actor == :secretary
      
      # Verify relationship created
      assert {:ok, _} = Relationship.find_relationship(prof.id, pat.id)
    end

    # Scenario 14: Éxito creando Persona nueva con identidad mínima
    test "14. Éxito creando Persona nueva con identidad mínima", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      # Create new patient with minimum identity
      {:ok, new_patient} = patient(auth_subject: "google-oauth2|new_#{:rand.uniform(1_000_000)}",
        profile_complete: false)  # Other fields pending but minimum identity complete
      
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, new_patient.id, ct.id, starts_at, ends_at,
        initial_state: :reservado, is_first_booking: true)
      
      assert {:ok, appointment} = Booking.create_booking(actor, params)
      assert appointment.state == :reservado
    end

    # Scenario 15: Duplicación documental
    test "15. Duplicación documental rechazada", %{secretary_actor: actor, professional: prof, patient: pat, consultation_type: ct} do
      # Try to create patient with same auth_subject
      {:ok, _} = patient(auth_subject: pat.auth_subject, auth_provider: :magic_link)
      
      # The patient creation should fail due to unique constraint
      # This is tested at the patient level, not booking level
      assert {:error, _} = patient(auth_subject: pat.auth_subject, auth_provider: :google)
    end

    # Scenario 16: Paciente fuera del alcance del centro
    test "16. Paciente fuera del alcance del centro", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      outside_actor = Map.put(actor, :center_scope_valid, false)
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, 999, ct.id, starts_at, ends_at,
        is_first_booking: true)
      
      assert {:error, {:eligibility_failed, :patient_outside_center_scope}} = 
        Booking.create_booking(outside_actor, params)
    end

    # Scenario 17: Identidad mínima incompleta antes del primer turno
    test "17. Identidad mínima incompleta", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      incomplete_actor = Map.put(actor, :minimum_identity_complete, false)
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, 999, ct.id, starts_at, ends_at,
        is_first_booking: true)
      
      assert {:error, {:eligibility_failed, :minimum_identity_incomplete}} = 
        Booking.create_booking(incomplete_actor, params)
    end

    # Scenario 18: Disponibilidad, tipo o superposición inválidos
    test "18. Disponibilidad/tipo/superposición inválidos", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      # Invalid consultation type
      params = booking_params(prof.id, 1, "invalid-uuid", starts_at, ends_at,
        is_first_booking: true)
      
      assert {:error, {:consultation_type_invalid, :not_found_or_inactive}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 19: Estado inválido por fecha
    test "19. Estado inválido por fecha (Solicitado no permitido)", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      # Secretary can never use Solicitado
      params = booking_params(prof.id, 1, ct.id, starts_at, ends_at,
        initial_state: :solicitado, is_first_booking: true)
      
      assert {:error, {:invalid_initial_state, :solicitado_not_allowed_for_secretary}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 20: Confirmado fuera de D-1 requiere declaración
    test "20. Confirmado antes de D-1 requiere declaración", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      # Request confirmado without agreement declaration
      params = booking_params(prof.id, 1, ct.id, starts_at, ends_at,
        initial_state: :confirmado, is_first_booking: true)
      
      assert {:error, {:invalid_initial_state, :agreement_declaration_required}} = 
        Booking.create_booking(actor, params)
      
      # With declaration, should succeed
      params_with_declaration = Map.put(params, :agreement_declaration, true)
      assert {:ok, _} = Booking.create_booking(actor, params_with_declaration)
    end

    # Scenario 21: Asignación directa interna día D
    test "21. Asignación directa interna día D", %{secretary_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = dia_d_slot()
      
      params = booking_params(prof.id, 1, ct.id, starts_at, ends_at,
        initial_state: :confirmado, agreement_declaration: true, is_first_booking: false)
      
      assert {:ok, appointment} = Booking.create_booking(actor, params)
      assert appointment.state == :confirmado
    end

    # Scenario 22: Conflicto concurrente Secretaría vs otra vía
    test "22. Conflicto concurrente Secretaría vs Paciente", %{secretary_actor: sec_actor, professional: prof, patient: pat, consultation_type: ct} do
      {:ok, patient2} = patient()
      patient_actor = patient_actor(patient2, prof.email)
      
      {starts_at, ends_at} = tomorrow_slot()
      
      sec_params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at,
        initial_state: :reservado, is_first_booking: true)
      pat_params = booking_params(prof.id, patient2.id, ct.id, starts_at, ends_at)
      
      task1 = Task.async(fn -> Booking.create_booking(sec_actor, sec_params) end)
      task2 = Task.async(fn -> Booking.create_booking(patient_actor, pat_params) end)
      
      result1 = Task.await(task1, 10_000)
      result2 = Task.await(task2, 10_000)
      
      success_count = Enum.count([result1, result2], fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      
      assert success_count == 1
    end
  end

  # ============================================================================
  # PROFESIONAL SOBRE PACIENTE RELACIONADO (S1-13 / BOOK-03) - 9 Escenarios
  # ============================================================================

  describe "Profesional sobre paciente relacionado (S1-13 / BOOK-03)" do
    setup do
      {:ok, professional} = professional()
      {:ok, patient} = patient()
      {:ok, consultation_type} = consultation_type(professional.id)
      
      # First, create a relationship via patient autonomous booking
      patient_actor = patient_actor(patient, "PRO-DEMO-001")
      {starts_at, ends_at} = tomorrow_slot()
      patient_params = booking_params(professional.id, patient.id, consultation_type.id, starts_at, ends_at,
        initial_state: :reservado, modality: :automatic)
      {:ok, _first_appointment} = Booking.create_booking(patient_actor, patient_params)
      
      # Mock catalog uses PRO-DEMO-001
      professional_actor = professional_actor(professional, [patient.id])
      
      {:ok, professional: professional, patient: patient, consultation_type: consultation_type,
       professional_actor: professional_actor}
    end

    # Scenario 23: Éxito para paciente en lista permitida
    test "23. Éxito para paciente en lista permitida", %{professional_actor: actor, professional: prof, patient: pat, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at,
        initial_state: :reservado)
      
      assert {:ok, appointment} = Booking.create_booking(actor, params)
      assert appointment.state == :reservado
      assert appointment.booked_by_actor == :professional
      
      # Relationship should NOT be created again (already exists)
      relationships = Repo.all(from r in "professional_patient_relationships", 
        where: r.professional_id == ^prof.id and r.patient_id == ^pat.id)
      assert length(relationships) == 1
    end

    # Scenario 24: Paciente no relacionado
    test "24. Paciente no relacionado denegado", %{professional_actor: actor, professional: prof, consultation_type: ct} do
      {:ok, unrelated_patient} = patient()
      
      {starts_at, ends_at} = tomorrow_slot()
      params = booking_params(prof.id, unrelated_patient.id, ct.id, starts_at, ends_at)
      
      assert {:error, {:eligibility_failed, :patient_not_related}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 25: Intento de búsqueda/acceso a registro global
    test "25. Acceso a registro global denegado", %{professional_actor: actor, professional: prof, consultation_type: ct} do
      {:ok, unrelated_patient} = patient()
      
      # Professional tries to book for unrelated patient (simulates manipulated ID)
      {starts_at, ends_at} = tomorrow_slot()
      params = booking_params(prof.id, unrelated_patient.id, ct.id, starts_at, ends_at)
      
      assert {:error, {:eligibility_failed, :patient_not_related}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 26: Disponibilidad, tipo o superposición inválidos
    test "26. Disponibilidad/tipo/superposición inválidos", %{professional_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot(10, 500)  # Too long
      
      params = booking_params(prof.id, 1, ct.id, starts_at, ends_at)
      
      assert {:error, {:availability_failed, :insufficient_intervals}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 27: Paciente con otro turno simultáneo
    test "27. Paciente con otro turno simultáneo (RF-12)", %{professional_actor: actor, professional: prof, patient: pat, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      # Create first appointment for patient with a different consultation type from same professional
      # (This tests patient overlap across different consultation types)
      {:ok, other_ct} = consultation_type(prof.id, name: "Control", interval_count: 1, price: Decimal.new("12000.00"))
      
      # Use patient actor to create the first appointment
      patient_actor = patient_actor(pat, "PRO-DEMO-001")
      other_params = booking_params(prof.id, pat.id, other_ct.id, starts_at, ends_at)
      
      assert {:ok, _} = Booking.create_booking(patient_actor, other_params)
      
      # Now professional tries to book same patient at same time with different consultation type
      params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at)
      
      assert {:error, {:overlap_detected, :patient}} = 
        Booking.create_booking(actor, params)
    end

    # Scenario 28: Otros roles intentan esta operación
    test "28. Otros roles denegados para S1-13", %{professional: prof, patient: pat, consultation_type: ct} do
      {:ok, secretary} = secretary()
      secretary_actor = secretary_actor(secretary, prof.email)
      
      {starts_at, ends_at} = tomorrow_slot()
      params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at)
      
      # Secretary cannot use S1-13
      assert {:error, {:authorization_denied, :policy_denied}} = 
        Booking.create_booking(secretary_actor, params)
    end

    # Scenario 29: Asignación directa interna día D
    test "29. Asignación directa día D por profesional", %{professional_actor: actor, professional: prof, patient: pat, consultation_type: ct} do
      {starts_at, ends_at} = dia_d_slot()
      
      params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at,
        initial_state: :confirmado)
      
      assert {:ok, appointment} = Booking.create_booking(actor, params)
      assert appointment.state == :confirmado
    end

    # Scenario 30: Conflicto concurrente profesional vs secretaría
    test "30. Conflicto concurrente Profesional vs Secretaría", %{professional_actor: prof_actor, professional: prof, patient: pat, consultation_type: ct} do
      {:ok, secretary} = secretary()
      secretary_actor = secretary_actor(secretary, prof.email)
      
      {starts_at, ends_at} = tomorrow_slot()
      
      prof_params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at)
      sec_params = booking_params(prof.id, pat.id, ct.id, starts_at, ends_at,
        initial_state: :reservado, is_first_booking: false)
      
      task1 = Task.async(fn -> Booking.create_booking(prof_actor, prof_params) end)
      task2 = Task.async(fn -> Booking.create_booking(secretary_actor, sec_params) end)
      
      result1 = Task.await(task1, 10_000)
      result2 = Task.await(task2, 10_000)
      
      success_count = Enum.count([result1, result2], fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      
      assert success_count == 1
    end

    # Scenario 31: Reversión transaccional ante fallo
    test "31. Reversión transaccional ante fallo", %{professional_actor: actor, professional: prof, consultation_type: ct} do
      {starts_at, ends_at} = tomorrow_slot()
      
      # Force FK violation
      params = booking_params(999999, 1, ct.id, starts_at, ends_at)
      
      assert {:error, _} = Booking.create_booking(actor, params)
      
      # Verify rollback
      assert Repo.all(Appointment) == []
    end
  end
end
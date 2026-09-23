defmodule Origen.Bookings.D1WindowTest do
  @moduledoc """
  Tests for D-1 window logic and initial state assignment.
  """

  use Origen.DataCase, async: true

  alias Origen.Bookings.D1Window
  alias Origen.Bookings.Errors

  @org_tz "America/Argentina/Buenos_Aires"

  setup do
    # Use a fixed date for testing: 2026-01-15 (Thursday)
    # D-1 would be 2026-01-14, Día D would be 2026-01-15
    fixed_now = ~U[2026-01-14 12:00:00Z]  # Noon on D-1 in UTC
    # In Argentina timezone (UTC-3), this is 2026-01-14 09:00:00
    {:ok, now: fixed_now}
  end

  describe "organization_timezone/0" do
    test "returns configured timezone" do
      assert D1Window.organization_timezone() == @org_tz
    end
  end

  describe "d1_cutoff/1" do
    test "returns 23:59 in org timezone for given date" do
      date = Date.from_iso8601!("2026-01-14")
      cutoff = D1Window.d1_cutoff(date)
      
      # 23:59 in Argentina = 02:59 UTC next day
      expected = ~U[2026-01-15 02:59:00Z]
      assert cutoff == expected
    end
  end

  describe "timing_for/2" do
    test "returns :before_d1 for date more than 1 day in future" do
      # Fixed now is 2026-01-14 12:00 UTC (09:00 Argentina)
      # 2026-01-16 is 2 days ahead -> before D-1
      assert D1Window.timing_for(Date.from_iso8601!("2026-01-16"), ~U[2026-01-14 12:00:00Z]) == :before_d1
    end

    test "returns :during_d1 for tomorrow before 23:59 cutoff" do
      # Tomorrow is 2026-01-15, now is 2026-01-14 12:00 UTC (09:00 Argentina)
      # D-1 is 2026-01-14, so 2026-01-15 is Día D... wait
      # Let me recalculate:
      # now = 2026-01-14 12:00 UTC = 2026-01-14 09:00 Argentina
      # org_today = 2026-01-14
      # requested = 2026-01-15 -> Date.add(org_today, 1) = 2026-01-15 -> during_d1 (if before cutoff)
      # D-1 cutoff for 2026-01-15 is 2026-01-14 23:59 Argentina = 2026-01-15 02:59 UTC
      # now (12:00 UTC) > cutoff (02:59 UTC) -> so it's :dia_d
      
      # Let's use a time before cutoff
      before_cutoff = ~U[2026-01-14 00:00:00Z]  # 21:00 previous day Argentina
      assert D1Window.timing_for(Date.from_iso8601!("2026-01-15"), before_cutoff) == :during_d1
    end

    test "returns :dia_d for tomorrow after 23:59 cutoff" do
      after_cutoff = ~U[2026-01-14 12:00:00Z]  # 09:00 Argentina, past 23:59 previous day
      assert D1Window.timing_for(Date.from_iso8601!("2026-01-15"), after_cutoff) == :dia_d
    end

    test "returns :dia_d for today" do
      assert D1Window.timing_for(Date.from_iso8601!("2026-01-14"), ~U[2026-01-14 12:00:00Z]) == :dia_d
    end

    test "returns :dia_d for past date" do
      assert D1Window.timing_for(Date.from_iso8601!("2026-01-13"), ~U[2026-01-14 12:00:00Z]) == :dia_d
    end
  end

  describe "is_dia_d/2" do
    test "returns true for today" do
      assert D1Window.is_dia_d(Date.from_iso8601!("2026-01-14"), ~U[2026-01-14 12:00:00Z])
    end

    test "returns true for tomorrow after cutoff" do
      assert D1Window.is_dia_d(Date.from_iso8601!("2026-01-15"), ~U[2026-01-14 12:00:00Z])
    end

    test "returns false for tomorrow before cutoff" do
      refute D1Window.is_dia_d(Date.from_iso8601!("2026-01-15"), ~U[2026-01-14 00:00:00Z])
    end
  end

  describe "initial_state_for/4" do
    # Patient tests
    test "patient before D-1 manual -> :solicitado" do
      assert D1Window.initial_state_for(:patient, :before_d1, :manual, []) == {:ok, :solicitado}
    end

    test "patient before D-1 automatic -> :reservado" do
      assert D1Window.initial_state_for(:patient, :before_d1, :automatic, []) == {:ok, :reservado}
    end

    test "patient during D-1 any modality -> :confirmado" do
      assert D1Window.initial_state_for(:patient, :during_d1, :manual, []) == {:ok, :confirmado}
      assert D1Window.initial_state_for(:patient, :during_d1, :automatic, []) == {:ok, :confirmado}
      assert D1Window.initial_state_for(:patient, :during_d1, nil, []) == {:ok, :confirmado}
    end

    test "patient día D -> denied" do
      assert D1Window.initial_state_for(:patient, :dia_d, :manual, []) ==
             {:error, {:d1_window_violation, :autonomous_channel_closed}}
    end

    # Secretary tests
    test "secretary before D-1 reservado -> ok" do
      assert D1Window.initial_state_for(:secretary, :before_d1, :reservado, []) == {:ok, :reservado}
    end

    test "secretary before D-1 confirmado without agreement -> error" do
      assert D1Window.initial_state_for(:secretary, :before_d1, :confirmado, []) ==
             {:error, {:invalid_initial_state, :agreement_declaration_required}}
    end

    test "secretary before D-1 confirmado with agreement -> ok" do
      assert D1Window.initial_state_for(:secretary, :before_d1, :confirmado, [agreement_declaration: true]) == {:ok, :confirmado}
    end

    test "secretary before D-1 solicitado -> error" do
      assert D1Window.initial_state_for(:secretary, :before_d1, :solicitado, []) ==
             {:error, {:invalid_initial_state, :solicitado_not_allowed_for_secretary}}
    end

    test "secretary during D-1 confirmado without agreement -> error" do
      assert D1Window.initial_state_for(:secretary, :during_d1, :confirmado, []) ==
             {:error, {:invalid_initial_state, :agreement_declaration_required}}
    end

    test "secretary during D-1 confirmado with agreement -> ok" do
      assert D1Window.initial_state_for(:secretary, :during_d1, :confirmado, [agreement_declaration: true]) == {:ok, :confirmado}
    end

    test "secretary during D-1 other state -> error" do
      assert D1Window.initial_state_for(:secretary, :during_d1, :reservado, []) ==
             {:error, {:invalid_initial_state, :only_confirmado_allowed_during_d1}}
    end

    test "secretary día D confirmado without agreement -> error" do
      assert D1Window.initial_state_for(:secretary, :dia_d, :confirmado, []) ==
             {:error, {:invalid_initial_state, :agreement_declaration_required}}
    end

    test "secretary día D confirmado with agreement -> ok" do
      assert D1Window.initial_state_for(:secretary, :dia_d, :confirmado, [agreement_declaration: true]) == {:ok, :confirmado}
    end

    # Professional tests
    test "professional before D-1 -> :reservado" do
      assert D1Window.initial_state_for(:professional, :before_d1, nil, []) == {:ok, :reservado}
    end

    test "professional during D-1 -> :confirmado" do
      assert D1Window.initial_state_for(:professional, :during_d1, nil, []) == {:ok, :confirmado}
    end

    test "professional día D confirmado -> ok" do
      assert D1Window.initial_state_for(:professional, :dia_d, :confirmado, []) == {:ok, :confirmado}
    end

    test "professional día D other state -> error" do
      assert D1Window.initial_state_for(:professional, :dia_d, :reservado, []) ==
             {:error, {:invalid_initial_state, :only_confirmado_allowed_dia_d}}
    end
  end

  describe "validate_initial_state/5" do
    test "validates patient before D-1 manual" do
      assert D1Window.validate_initial_state(:patient, Date.from_iso8601!("2026-01-16"), :solicitado, :manual, []) == :ok
    end

    test "validates patient día D denied" do
      assert D1Window.validate_initial_state(:patient, Date.from_iso8601!("2026-01-15"), :solicitado, :manual, []) ==
             {:error, {:d1_window_violation, :autonomous_channel_closed}}
    end
  end
end
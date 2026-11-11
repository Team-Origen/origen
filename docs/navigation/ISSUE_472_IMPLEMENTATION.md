# Issue #472 — Implementation evidence

## Professional requests and navigation

`/profesional/solicitudes` replaces the inactive navigation entry and owns the
existing accept/reject cards and actions relocated from Agenda. Each card shows
patient identity, consultation type, status and appointment date/time in the
organization timezone. No daily selector remains: a legacy `date` parameter
neither narrows the list nor produces a date error.

`Booking.list_professional_pending_requests/1` revalidates the active professional
session and filters SQL by its account and requested status, ordered by start time
and ID ascending. Daily Agenda retains its date contract and lifecycle operations.
Accept/reject permissions, status transitions and stale-request errors remain
unchanged. No secretary request-management capabilities are introduced.

The professional Patients destination remains pending #471; secretary patient
search and professional patient selection retain working destinations. No active
navigation links were removed. There is no cross-tab real-time synchronization.

Functional RED: two new general-list assertions failed before implementation
(exit 2). GREEN: 37 professional Agenda/Requests tests passed. Full integrated
candidate: 1115 passed,32 skipped,8 excluded (exit 0); assets/format/diff passed.
Sandbox ownership messages remain in test output without established cause.
Browser screenshots and independent verification remain unavailable from the
handoff; these results do not constitute visual or independent approval.

## Professional settings

The existing approval panel and both selectors move from Agenda to Settings,
immediately after consultation types and before agenda interval. The form remains
owned by the parent LiveView within the existing availability component slot;
no form event targets or business rules change. Settings remain professional-only.
Changing mode affects only new reservations, leaving existing pending requests
and occupied slots unchanged. Existing profile and availability editors remain.

RED: the new adjacency assertion failed before moving the panel (exit 2).
GREEN: 44 Agenda/Requests/catalog/manual-approval tests passed, including saving
both selectors and preservation of pending requests. DOM position is verified;
real-browser desktop/mobile presentation remains unverified.

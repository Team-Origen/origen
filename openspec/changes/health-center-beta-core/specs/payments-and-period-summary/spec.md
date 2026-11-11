# Payments and period summary

## Requirements

### Requirement: Single total payment and correction

A confirmed or attended appointment MAY have exactly one total payment in `pending` or `paid`, using cash or transfer. Payment MUST NOT block booking, and a pending approval request MUST NOT be marked paid. Professional may operate own appointments and Secretary all appointments; each payment record MUST retain method, actor, and date. Patient may only inspect final price and payment state; Administrator has no financial access. Before payment, Professional and Secretary MAY change that appointment’s final price without changing the consultation catalogue. Payment locks the price. They MAY reverse a paid mark after a brief confirmation, without required written reason; the correction MUST preserve previous action, actor, and date, return the payment to pending, recalculate summaries, and unlock the price. It is not a refund.

#### Scenario: Correct erroneous paid mark

- GIVEN an appointment is marked paid
- WHEN its authorized operator confirms reversal
- THEN its payment becomes pending and its final price becomes editable
- AND the previous mark and correction actor/time remain traceable

### Requirement: Cancellation and summary scope

Cancellation MUST NOT delete payment. Refunds, credits, partial payments, receipts, and payment transfers are outside the system. Summary periods MUST group by appointment date, not collection date. Professionals see their own summary; Secretary sees one Professional at a time; Administrator sees none. Paid includes every paid appointment in the period, including cancelled and no-show. Pending includes only confirmed or attended unpaid appointments. It excludes unpaid cancelled, requested, rejected, expired, and no-show appointments. `total considered` is paid plus pending and MUST NOT be presented as debt, monthly cash, net income, or available balance.

#### Scenario: Late payment updates appointment period

- GIVEN an appointment belongs to a prior period and is unpaid
- WHEN payment is recorded later
- THEN the paid amount contributes to the appointment’s period
- AND it does not become a collection-date summary

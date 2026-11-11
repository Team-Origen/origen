# Staff accounts and professional settings

## Requirements

### Requirement: Professional profile and settings

A Professional MUST complete name, surname, specialty, free-text licence type, and free-text licence number before appearing to patients for booking. Photo is optional and MUST NOT block access, registration, or booking. The Professional MAY configure their own agenda interval, consultation types/duration/price, weekly hours, minimum notice, and booking horizon. Secretary MUST NOT read or modify professional profile or settings.

#### Scenario: Incomplete professional is not bookable

- GIVEN a Professional account is active but required profile data is incomplete
- WHEN a Patient lists bookable Professionals
- THEN that Professional is absent
- AND the Professional may still access and prepare their settings

### Requirement: Administrative account lifecycle

Administrator MAY create, edit, deactivate, and reactivate only Professional and Secretary accounts, including account email. It MUST NOT gain patient, appointment, payment, or professional-settings authority by role hierarchy. Deactivation MUST immediately stop staff access and new patient bookings for a Professional, preserve history and existing appointments/requests, and show the Administrator the count of future affected appointments for Secretary follow-up. Reactivation restores access but MUST NOT restore cancelled appointments.

#### Scenario: Urgent professional deactivation

- GIVEN a Professional has future appointments and pending requests
- WHEN an Administrator deactivates that account
- THEN access and new bookings stop immediately
- AND existing records remain unchanged
- AND no appointment is automatically cancelled

# Patient identity and access

## Requirements

### Requirement: Assisted identity and unique patient

Staff MUST search for an existing patient before registration. Professional and Secretary MAY register an absent patient and create an appointment without a personal account or email. Assisted registration MUST require name, surname, DNI, birth date, and phone; email is optional, may be shared, and need not be phone-verified. DNI MUST remain unique.

#### Scenario: Professional registers an absent patient

- GIVEN a Professional searches the exact DNI inside appointment creation
- AND no patient exists
- WHEN the Professional supplies every required assisted-registration field
- THEN the system creates one patient without requiring email or personal access
- AND the Professional MAY create the appointment through the normal booking rules

### Requirement: Personal access and email maintenance

A Patient MUST access only their own appointments through a magic link sent to a linked email, without a password. Assisted registration MUST NOT grant access automatically. Authorized Professional or Secretary staff MAY link or replace that email after operational identity checking outside the system. The new email MUST complete magic-link proof; replacement MUST preserve the same patient/history, reject an email already linked elsewhere, invalidate the patient’s previous links and sessions, and record actor and time. Public registration MUST return a general response that does not reveal DNI existence or patient data.

#### Scenario: Staff links later personal access

- GIVEN an assisted patient has no personal-access email
- WHEN authorized staff locate that patient and add an unused email
- THEN the patient remains the same identity with the same history
- AND only proof through a magic link to the new email may enable personal access

#### Scenario: Public DNI collision does not disclose data

- GIVEN a public registration submission matches an existing DNI
- WHEN the submission is processed
- THEN the response MUST NOT disclose the matching patient or their data
- AND it MUST NOT link the submitting person to that patient

### Requirement: Identity corrections

Authorized Professional and Secretary staff MAY correct name, surname, DNI, birth date, and phone within their permissions. A correction MUST reject a DNI already assigned to another patient. Patients may inspect, but MUST NOT autonomously edit, identity data or email in this beta.

#### Scenario: Duplicate DNI correction

- GIVEN a staff member attempts to change a patient DNI to one used by another patient
- WHEN the correction is submitted
- THEN it is rejected
- AND neither patient identity changes

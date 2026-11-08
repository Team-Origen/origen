# Origen navbar prototype

Throwaway visual comparison for Patient, Professional, Secretary and Administrator navigation in issue #369. This is not a production navbar, authentication flow, or implementation of pending screens. No application routes, shared styles, permissions, or issues are changed.

## Open the preview

From the repository root:

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

Open <http://localhost:4173/prototypes/navigation/>. Stop the preview with Ctrl+C. This serves the checkout locally; do not bind it to a public interface. Alternatively, open `index.html` directly in a browser; JavaScript and logos use local relative paths.

## Compare designs

- `?variant=A`: single-row white navbar (default).
- `?variant=B`: single-row petroleum-blue navbar, using the primary logo. Per the user's visual comparison request, white variants A/C use the alternate dark-background asset; this swaps the previous prototype assignments without changing backgrounds. This prototype-only choice is not a change to the production identity guidelines.
- `?variant=C`: brand/account row plus a separate navigation tab row.

Use the floating comparison controls to switch; left/right arrow shortcuts apply outside interactive controls. The URL preserves the design and simulated page. Example:

```text
http://localhost:4173/prototypes/navigation/?variant=A#role=profesional&page=profile
```

The role selector is a prototype-only control, not product navigation. It resets to **Mis turnos** for Patient, **Agenda** for Professional and Secretary, or **Cuentas** for Administrator. Browser Back/Forward follows fragment navigation; the comparator replaces only its design query parameter.

## What to try

1. Patient: switch between **Mis turnos** and **Reservar turno**, including the page's reservation action and return link.
2. Professional: **Agenda → Crear turno → Agenda**; **Ajustes → Mi perfil → Ajustes**. The parent section remains selected in both subpages.
3. Visit Professional **Resumen económico**, explicitly marked as a pending screen with fictional data.
4. Open the account dropdown, activate **Cerrar sesión**, then **Volver a la simulación**. This never calls `/logout`, terminates a session, or changes browser credentials. Patient logout behavior is intentionally not specified by this preview.
5. Try Tab, Enter/Space on the native account disclosure, Escape to close it, and clicking outside it. Check visible focus, zoom and narrow layouts in a browser before accepting a design.

All action feedback is illustrative. Reservation, cancellation, payment, registration, settings and profile operations do not reach a server. Names, appointments, dates and amounts are fictional. The screens provide context for judging the navbar; they are not redesign proposals for existing workflows.

## Identity and boundaries

Sources: `docs/visual-design-system.md`, `docs/navigation/URL_CONVENTIONS.md`, existing production screen links, and the navigation proposal in this conversation.

The preview uses the approved primary `#0A3847`, secondary `#35545A`, accent `#DDE6DB`, white background and original PNG logos. Supporting borders use the existing neutral token. It does not reuse the legacy off-white background as the new brand background.

This standalone HTML deliberately approximates component appearance without loading Phoenix, PetalComponents, authentication or application data. A future production implementation must use the documented PetalComponents primitives; this disposable HTML/CSS is not a replacement component library. There are no dependencies, remote fonts, storage, network mutations, or production route registrations.

Secretary has **Agenda**, **Pacientes** and **Resumen económico**, with a fictional Professional selector inside Agenda and Summary, not a separate Professionals section. Agenda → Pacientes reuses the assisted-booking entry as a proposed connection. Secretary can observe a pending request but cannot accept/reject it (#284); professional settings and account administration are excluded. Both Agenda and Summary are marked pending. No `/secretaria/agenda/crear` route is invented. Try `#role=secretaria&page=agenda`, `#role=secretaria&page=patients` and `#role=secretaria&page=summary`. Changing the Professional updates fictional agenda and summary content in memory only. Administrator has a single **Cuentas** navigation item and the same account/logout dropdown. Open `?variant=B#role=administrador&page=accounts`. The current creation/invitation form is represented alongside explicitly pending #279 account editing (including email), deactivation with a fictional affected-future-appointment count, and reactivation without restoring cancelled appointments. Actions are illustrative feedback only: no accounts, credentials, invitations, emails, sessions or appointments change. All actions stay inside Cuentas without inventing additional URLs. There are no Administrator links to patients, agendas, financial summaries or professional settings. Phone verification remains an unresolved beta flow and is not turned into a prerequisite or a profile-edit permission.

## Verification limits

JavaScript syntax, deterministic role/page selection, section ownership, variant cycling, representative simulated click handlers and logout/re-entry can be checked locally without the application. These do not prove browser rendering, native disclosure behavior, focus/zoom, or actual logo visibility. Those require opening the prototype in a browser; unavailable checks must not be represented as passed.

# Origen visual design system

Use this foundation for every new Origen interface. PetalComponents v4.16.1 is the only source of visual UI primitives; application code supplies composition, content, and layout utilities.

## Quick implementation path

1. Choose the PetalComponents primitive that matches the interaction.
2. Use its semantic `color`, `variant`, `size`, and `radius` attributes before adding layout utilities.
3. Use the tokens in `assets/css/app.css`; do not introduce one-off color, spacing, or radius values.
4. Verify keyboard behavior, visible focus, non-color cues, and WCAG 2.2 AA contrast.

## Color system

The source colors are anchors inside accessible ramps, not interchangeable text colors.

| Role | Source color | Ramp anchor | Use |
| --- | --- | --- | --- |
| Primary | `#0A3847` | `primary-700` | Headings, primary brand text, strong brand actions |
| Secondary | `#35545A` | `secondary-700` | Supporting text and secondary brand actions |
| Accent | `#DDE6DB` | `accent-200` | Quiet highlighted surfaces only |
| Neutral | `#AFBAB4` | `gray-400` | Borders and non-essential surface treatment only |
| Background | `#F6F6F4` | `gray-50` / `page` | Page background |

### Available tokens

- Brand ramps: `primary-50..950` and `secondary-50..950`.
- Surface ramp: `accent-50..950`; use pale stops for surfaces.
- Neutral ramp: `gray-50..950`; PetalComponents consumes this role for neutral UI.
- Semantic aliases: `page`, `surface`, `surface-muted`, `border`, `text`, and `text-muted`.
- Status ramps: PetalComponents `info`, `success`, `warning`, and `danger`; never substitute a brand color for state meaning.

Primary and secondary source colors pass WCAG AA for normal text on the page background. Accent and neutral source colors are not normal-text colors and must never be the only cue for an essential state.

## Component semantics

| Need | PetalComponents choice | Rule |
| --- | --- | --- |
| Primary action | `<.button color="primary">` | One dominant action per decision area |
| Secondary action | `<.button color="secondary" variant="outline">` | Use for a genuine alternate action |
| Destructive action | `<.button color="danger">` | Reserve for destructive or irreversible intent |
| Status | `<.badge>` | Include a meaningful text label; a dot is decorative |
| Feedback | `<.alert>` or toast | Match `info`, `success`, `warning`, or `danger` to meaning |
| Input | `<.field>` | Keep label, help, error, and input semantics together |
| Grouped content | `<.card>` | Use the component structure instead of a styled container clone |
| Dialog | `<.modal>` or `<.alert_dialog>` | Use alert dialog only for consequential confirmation |
| Structured data | `<.table>` / `<.data_table>` | Preserve header and row semantics |

Before using a component, inspect its v4.16.1 schema. Component attributes are the customization API; utility classes are for composition and responsive layout, not reimplementing the component.

## Typography

- Use the system sans stack defined by `--font-sans`; no external font is required.
- Use PetalComponents typography primitives for headings, paragraphs, supporting text, and prose.
- Preserve semantic heading order; visual size does not determine document rank.
- Use normal body text at `text-base` with comfortable line height. Use `text-sm` only for supporting information, never to hide complexity.
- Use weight and spacing before color to establish hierarchy.

## Spacing and layout

Use Tailwind's default 4 px spacing scale through standard utilities.

| Relationship | Preferred spacing |
| --- | --- |
| Label to control or tightly related items | `gap-2` (8 px) |
| Fields or related controls | `gap-4` (16 px) |
| Content groups | `gap-6` (24 px) |
| Major sections | `gap-8` to `gap-12` (32–48 px) |

Prefer PetalComponents `<.container>` for page width. Keep forms readable rather than stretching controls across wide screens.

## Radii

| Token | Value | Use |
| --- | --- | --- |
| `radius-control` / `--pc-radius` | 10 px | Buttons, inputs, badges, alerts |
| `radius-surface` | 12 px | Cards and grouped surfaces |
| `radius-dialog` | 16 px | Modals and prominent overlays |
| `rounded-full` | Full | Avatars, status dots, and intentional pills only |

Prefer each PetalComponents component's `radius` attribute. Do not override its internal corners with arbitrary classes.

## Logo

The canonical asset is `priv/static/images/origen-logo.png`, a 1278 × 1231 RGBA PNG with real transparency.

- Keep its aspect ratio and transparent background.
- Provide `alt="Origen"` when the logo identifies the product; use `alt=""` only when adjacent text already names Origen.
- Give rendered images explicit dimensions to reduce layout shift.
- Do not recolor, crop, distort, add a background plate, or use the previous Phoenix logo as product branding.

## Accessibility contract

- Meet WCAG 2.2 AA: at least 4.5:1 for normal text and 3:1 for large text and meaningful UI graphics.
- Never communicate status through color alone. Pair it with text and, where useful, an icon.
- Preserve PetalComponents focus, disabled, error, and loading states.
- Every control needs an accessible name; icon-only buttons require `aria-label`.
- Errors must identify the affected field and explain the correction.
- Keep focus order aligned with reading order and return focus appropriately after overlays close.
- Test keyboard operation and zoom/reflow before considering a screen complete.

## Examples

```heex
<.button color="primary">Save changes</.button>
<.button color="secondary" variant="outline">Cancel</.button>

<.badge color="success" variant="soft" dot label="Active" role="status" />

<.alert color="danger" variant="callout" with_icon heading="Changes not saved">
  Correct the highlighted fields and try again.
</.alert>
```

## Prohibited usage

- No DaisyUI component classes such as `btn`, `card`, `alert`, or `modal` in new implementation code.
- No hand-built visual primitives when PetalComponents provides the behavior.
- No scattered hex, RGB, HSL, or OKLCH literals outside the visual-system token block.
- No accent or neutral color as normal text or as the sole state indicator.
- No brand color used to mean success, warning, or danger.
- No arbitrary spacing or radius values without extending this standard first.
- No screen-specific overrides of PetalComponents internals.

Existing generated scaffold styling is not precedent. Migrate it to this standard when that surface enters an approved implementation scope; do not expand the current Part 1 foundation into screen redesign.

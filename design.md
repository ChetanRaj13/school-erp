# Design System — School ERP
**Status:** Direction agreed, not yet implemented in the app.
**Last updated:** 2026-08-14
**Source:** Palette, type, shape, illustration, and component rules below are taken directly
from `contra_design_language.md` (a design-language extraction done from the reference kit
image itself). Where this doc adds something the extraction doesn't specify — role-accent
wayfinding, the schedule/table/checklist screen mappings — it's marked as an addition, not
part of the source extraction.

---

## 1. Why this redesign

The previous visual identity (`warm_backdrop`, `glass_card`, photo backgrounds like
`mountain_trail`/`study_hall`) is a soft-glassmorphism-over-stock-photo look — a very common
"education app" template right now. It doesn't read as belonging specifically to this school
or this product. Goal for this pass: something distinctive, grounded in this app's actual
content (roles, data, day-to-day school rhythms), not a generic SaaS/ed-tech default.

We explored a few school-grounded directions (a ledger/register-inspired look, a
timetable-grid-as-visual-grammar look, a chalk/slate look) before settling on a concrete
reference: a bold flat-illustration UI kit ("Contra wireframe kit" style — black-outlined
characters, saturated color-blocked panels, chunky pill buttons, no gradients or soft
shadows). It was chosen because it already contains close analogs for most of this app's real
screen types — login/signup, settings, payments, checklists, chat/contacts, stat cards, and
list views — so the mapping to real screens is direct rather than aspirational.

---

## 2. Design tokens (source of truth: `contra_design_language.md`)

**Palette** — exact hex values, no substitutions:

| Token | Hex | Usage |
|---|---|---|
| Primary Yellow | `#FFC700` | CTAs, highlights, active states, accents |
| Coral/Orange | `#FF6B47` | Secondary actions, tags, warnings, energetic accents |
| Teal/Mint | `#00D4AA` | Success states, positive indicators, fresh accents |
| Royal Blue | `#2E5BFF` | Primary brand color, links, navigation, trust elements |
| Hot Pink | `#FF6B9D` | Tertiary accent, tags, playful elements |
| Black | `#1A1A1A` | Primary text, icons, illustration outlines |
| White | `#FFFFFF` | Backgrounds, text on dark, card surfaces |
| Light Gray | `#F5F5F5` | Subtle backgrounds, dividers, disabled states |

**Color usage rules** (from the extraction — hold these throughout implementation):
- Backgrounds are solid, saturated colors — never gradients
- Cards frequently sit on colored section backgrounds, not just white
- High contrast is mandatory: dark text on light, light text on dark
- Color groups related content and indicates state — it's functional, not decorative

> **Change from the earlier draft of this doc:** background moves from a warm Cream
> (`#FCF6EC`) to White (`#FFFFFF`) with Light Gray (`#F5F5F5`) for subtle/secondary surfaces,
> and the Admin role accent moves from a custom Navy to Royal Blue (`#2E5BFF`) — both to match
> the actual extracted palette rather than an approximated one.

**Role accent (wayfinding — addition, not part of the source extraction):** each role gets
exactly one signature color, applied only to that role's app bar, active nav state, and
primary buttons — everything else stays on the neutral White/Light Gray/Black so the accent
stays meaningful instead of decorating everything.

| Role | Accent |
|---|---|
| Admin | Royal Blue |
| Principal | Coral/Orange |
| Teacher | Teal/Mint |
| Student | Primary Yellow |
| Parent | Hot Pink |
| Shared/system (login, settings, uploads) | Black on White, no accent |

**Typography:**

| Role | Style |
|---|---|
| Display/Headings | Bold sans-serif, tight letter-spacing, 24–32px |
| Subheadings | Bold sans-serif, 18–20px |
| Body | Regular/Medium sans-serif, 14–16px, comfortable line-height |
| Captions/Labels | Medium sans-serif, uppercase or small case, slightly muted |
| Buttons | Bold sans-serif, sentence case, generous letter-spacing |

- Family: geometric sans-serif throughout — Inter, Poppins, or Circular. No serifs anywhere.
- Weight: headings 700–800, body 400–500
- Mix of uppercase (labels/tags) and sentence case (headings); strong size contrast between
  hierarchy levels
- *Addition, not in the source extraction:* a handwritten script accent (Caveat or similar)
  for one-off greeting copy only ("Welcome back, Suresh") — never for data or controls. Cut
  this if it doesn't earn its place once real screens are built.

**Shape & geometry:**

| Element | Treatment |
|---|---|
| Buttons | Pill (`999px`) or large radius (`16–24px`) |
| Cards | Large rounded corners (`16–24px`) |
| Inputs | Rounded rectangles (`12–16px`) |
| Avatars | Perfect circles |
| Tags/chips | Pill shape |
| Icons | Rounded stroke, 2px weight |

Radii scale: `sm: 8px, md: 16px, lg: 24px, pill: 999px`
Spacing scale: `xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px` — generous padding inside
cards, comfortable gaps between elements, clear airy section breaks.

**Illustration style** — one of the most distinctive parts of this language, worth protecting
carefully during implementation:
- Flat, 2D, black-and-white (or single-color) line art
- Simplified human figures, bold black outlines, minimal facial features, expressive poses
- Consistent thick stroke weight (~3–4px), no shading or gradients — pure silhouette/outline
- Diverse body types and activities represented
- Used for empty states, onboarding, decorative headers, feature highlights — not scattered
  everywhere as generic texture

> **Correction from the earlier draft:** the previous version of this doc suggested
> "halftone-dot clusters" as a decorative texture. That wasn't actually part of the
> reference kit — the real decorative language is the black-and-white line illustration
> described above. Use illustrations for that role instead.

**Iconography:** rounded, friendly, 2–2.5px stroke weight, 24px standard / 20px in dense
areas, colored black or matching the section's accent color.

**Elevation & depth:** no drop shadows anywhere — this is a flat design system. Depth comes
from color contrast (colored cards on colored backgrounds), solid 2px borders (black or
colored outlines), and spacing/scale — never from shadow.

---

## 3. Component patterns (from the extraction)

**Buttons**
- Primary: solid yellow or blue background, black or white bold text, pill shape
- Secondary: outlined, colored border, transparent or white fill
- Large touch targets, prominent placement

**Cards**
- Colored backgrounds (yellow, pink, blue, teal) — not exclusively white
- Rounded corners, clear title + subtitle + action structure
- Often contain illustrations or avatars

**Inputs & forms**
- Rounded rectangles with light borders
- Icon prefixes common (search, mail, lock)
- Floating labels or placeholder text, clean minimal error states

**Lists**
- Avatar + text + action icon/metatext
- Subtle dividers or card-based separation
- Color-coded status indicators

**Navigation**
- Bottom tab bar: icon + label, active state highlighted with color
- Top bar: minimal — back arrow + title only

**Tags & chips**
- Pill-shaped, solid color backgrounds or colored borders, small bold text

**Layout principles**
- Mobile-first, portrait, single-column vertical flow
- Related items clustered in colored cards
- Generous whitespace — never cramped
- Alternating colors and illustration placement create visual rhythm across a flow

---

## 4. Guardrail specific to this project

This is a real ERP with genuinely dense data screens (gradebook matrices, fee ledgers,
attendance grids) that the reference kit itself doesn't have an example of. The kit's playful
full-bleed color panels and list/card patterns above are right for headers, hero stats, empty
states, and most list-style screens — dense tables should stay legible and structured,
reskinned with this token system (hairline dividers, pill status tags, tabular numerals), not
literally replaced with illustration panels.

---

## 5. Screen-by-screen mapping

### Admin (Royal Blue)
- `admin_dashboard` — full-bleed Royal Blue hero with the day's single most important number
  set huge in white; stat cards below on white/light gray
- `fee_management`, `late_fees`, `payroll`, `emi_financing`, `offline_payment` — "Payments"
  card treatment: headline amount huge, chunky pill CTA beneath; Coral for overdue amounts
- `approval_queue` — checklist rows: round toggle, black hairline divider, pill status tag
- `messages` — chat/contact-list treatment: circular avatar, name, preview, unread pill
- `announcements` — feed cards with a color tag strip (color = urgency)
- `vendor_performance`, `vendor_procurement` — list rows with a flat icon badge and a small
  horizontal score bar
- `admin_hrm_overview`, `admin_finance_overview` — minimal-chrome line/bar charts, Royal Blue,
  pill legend chips above, no gridlines

### Principal (Coral/Orange)
- `principal_dashboard` — same big-number hero as Admin, in Coral, surfacing the one number a
  principal checks first; Insights analytics section below, chart-screen style
- `budget_screen` — "Payments" treatment for the top-line number; line items below as
  checklist rows with Teal/Coral pill tags for under/over budget

### Teacher (Teal/Mint)
- `gradebook` — real matrix kept intact; black hairline dividers, grade values as
  color-blocked pill tags, tabular numerals, sticky Teal header row
- `teacher_attendance` — checklist rows, round present/absent toggle per student
- `leave_requests` — checklist/status-row treatment, Teal accent
- `lesson_resources` — list rows with a flat file-type icon badge
- `teacher_assignments` — cards with a color-blocked subject corner tag, due date, submission
  progress indicator
- `teacher_summary` — chart-screen treatment, Teal, at-risk-students list as stacked
  checklist rows

### Student (Primary Yellow)
- `student_overview` — large illustrated avatar (line-art style), name, 2–3 stat pills
  (attendance %, grade average, pending assignments)
- `student_schedule` — vertical time-block stack, current period highlighted full-bleed Yellow
- `student_assignments` — checklist rows, Yellow accent
- `student_library` — list rows with flat icon and subject tag
- `student_progress` — big-number hero for the headline stat, trend chart below in Yellow

### Parent (Hot Pink)
- `parent_overview` — one card per linked child (avatar + name + headline stat), tap through
  to that child's detail
- `parent_fees` — "Payments" treatment, Hot Pink, "Pay Now" pill CTA
- `parent_notifications` — feed treatment, Hot Pink tag strip
- `parent_schedule` — time-block stack as in student_schedule, labeled per child if more than
  one is linked
- `waiver_requests` — checklist/status-row treatment, Hot Pink accent

### Shared / system (Black on White, no role accent)
- `login_screen` — email/password fields, one full-width pill button, small line-art
  illustration accent near the top
- `splash_screen` — quiet full-bleed White or Royal Blue with the school mark centered
- `unauthorized_screen` — flat line-art character illustration, one line of plain copy, one
  pill button back to a safe screen
- `settings_screen` — grouped rows, icon badge + label + toggle/chevron
- `document_review_screen` (incl. upload), `omr_upload_screen` — dashed-outline drop zone or
  camera-icon button; pending items as checklist rows with a pill status tag
- `timetable_grid_screen` — stays a true grid (shared across roles) — black hairlines,
  role-accent color-blocked cells per subject; does not switch to the time-block treatment
  used for the single-role schedule screens

---

## 6. Suggested implementation order

1. Tokens + `login_screen` + `settings_screen` first — cheapest, most reusable components,
   good place to catch problems in the token system before it's threaded through ~25 screens
2. One full profile end-to-end — Teacher is the best test case, since it exercises every
   component type (table, chart, checklist, list) in one profile
3. Review the reskinned gradebook/attendance screens against real data before rolling out
   further — dense tables are the highest-risk part of this restyle
4. Remaining profiles, in order of least to most screens: Principal → Parent → Admin/Student →
   remaining shared screens

---

## 7. Design tokens (JSON, from the extraction)

```json
{
  "colors": {
    "primary": "#FFC700",
    "secondary": "#FF6B47",
    "tertiary": "#00D4AA",
    "brand": "#2E5BFF",
    "accent": "#FF6B9D",
    "text": "#1A1A1A",
    "background": "#FFFFFF",
    "surface": "#F5F5F5"
  },
  "radii": {
    "sm": "8px",
    "md": "16px",
    "lg": "24px",
    "pill": "999px"
  },
  "spacing": {
    "xs": "4px",
    "sm": "8px",
    "md": "16px",
    "lg": "24px",
    "xl": "32px"
  },
  "typography": {
    "family": "Geometric Sans-Serif (e.g., Inter, Poppins, Circular)",
    "headingWeight": "700-800",
    "bodyWeight": "400-500"
  }
}
```

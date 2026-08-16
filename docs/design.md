# School ERP — Visual Design System (Contra Wireframe Kit Style)

## 0. Shared Style System

We are styling the School ERP Flutter app to match a bold flat-illustration UI kit ("Contra wireframe kit" style: bold black-outlined characters, saturated color-blocked panels, chunky pill buttons, no gradients/soft shadows).

### Palette
- Cream base `#FCF6EC` / `#FFFFFF` — default screen background
- Ink `#16171B` / `#1A1A1A` — primary text, outlines
- Golden yellow `#FFC93C` / `#FFC700` (Student)
- Coral `#FF5A3C` / `#FF6B47` (Principal)
- Teal `#00A99D` / `#00D4AA` (Teacher)
- Bubblegum pink `#F1739F` / `#FF6B9D` (Parent)
- Navy / Royal Blue `#1A1F3C` / `#2E5BFF` (Admin)

### Role Accent (Wayfinding)
- Admin → Navy / Royal Blue (`#2E5BFF`)
- Principal → Coral (`#FF6B47`)
- Teacher → Teal (`#00D4AA` / `#00877D`)
- Student → Golden yellow (`#FFC700` / `#B8860B`)
- Parent → Pink (`#FF6B9D` / `#E0568C`)
- Shared/system screens (login, settings, uploads) → Ink on cream/white, no role accent

### Typography
- Display/headings: `GoogleFonts.poppins` / Space Grotesk Bold — large, tight tracking
- Body: `GoogleFonts.inter` — regular/medium weight, generous line-height
- Tabular numerals for dense numbers and data tables

### Shape & Component Language
- Buttons: fully rounded pill shape (`AppRadii.button` = 999), flat fill, no shadow, bold ink label
- Cards: 24px corner radius (`AppRadii.card`), flat surface with hairline border (`AppColors.glassBorder`), no drop shadows
- Icons: flat, friendly stroke
- Data tables/lists (gradebook, attendance, ledgers): keep real tabular structure, reskin row dividers with hairline borders, use color-blocked pill tags for status/grade values, tabular-numeral font for numbers

---

## 1. Admin (Navy)
- **admin_dashboard**: hero panel in solid Navy, full-bleed, with top metric huge in cream/white. Section below with outlined stat cards.
- **fee_management, late_fees, payroll, emi_financing, offline_payment**: full-bleed color card showing headline amount huge, chunky pill CTA button beneath. Coral for overdue/late amounts, Navy for routine.
- **approval_queue**: checklist format — each pending item as a row with round toggle/checkbox, hairline divider, pill status tag (Pending/Approved/Rejected).
- **messages**: circular avatar, name in bold sans, last-message preview in muted ink, unread count pill.
- **announcements**: card per announcement with a color tag strip on left edge (color = urgency), bold headline, one-line preview.
- **vendor_performance, vendor_procurement**: row with flat icon badge, name, horizontal rating/score bar.
- **admin_hrm_overview, admin_finance_overview**: line/bar chart screens on cream/white with Navy line/bars, pill legend chips above, minimal-chrome charts.

---

## 2. Principal (Coral)
- **principal_dashboard**: big-number hero in Coral, surfacing school-wide attendance / key metric. Insights analytics section below with Coral accents.
- **budget_screen**: top-line budget-vs-actual number card, checklist-style line items below with pill tag per line item showing under/over budget in Teal/Coral.

---

## 3. Teacher (Teal)
- **gradebook**: real matrix/table structure (student × assignment). Hairline row dividers, grade values as small color-blocked pill tags (Teal for A/B, Coral for at-risk), tabular numerals throughout, header row in Teal.
- **teacher_attendance**: checklist/todo rows with round present/absent toggle in place of checkbox, name in bold sans.
- **leave_requests**: checklist/status-row treatment with Teal accent.
- **lesson_resources**: playlist-style rows with flat file-type icon badge, title, subtitle metadata.
- **teacher_assignments**: card with color-blocked corner tag for subject, due date in bold, small progress indicator for submissions received.
- **teacher_summary**: chart-screen treatment matching analytics in Teal, plus at-risk-students card styled as a stack of checklist rows.

---

## 4. Student (Golden Yellow)
- **student_overview**: large circular avatar, name, stat pills (attendance %, current grade average, pending assignments).
- **student_schedule**: time-labeled period blocks in vertical stack, current period highlighted in Yellow.
- **student_assignments**: checklist-row treatment with Yellow accent and student-facing copy ("Due" dates).
- **student_library**: card with flat icon, title, subject tag.
- **student_progress**: big-number/chart hero for headline stat, trend chart in Yellow.

---

## 5. Parent (Pink)
- **parent_overview**: destination card per child, avatar + name + headline stat, tap through to child detail.
- **parent_fees**: payments screen treatment, Pink accent, chunky "Pay Now" pill CTA.
- **parent_notifications**: news feed treatment with Pink tag strip.
- **parent_schedule**: time block treatment with Pink accent.
- **waiver_requests**: checklist/status-row treatment with Pink accent.

---

## 6. Shared / System Screens
- **login_screen**: clean flat layout with email, password, full-width pill button in Ink, subtle header greeting.
- **splash_screen**: clean cream/white with school mark centered.
- **unauthorized_screen**: flat icon/illustration, clear explanation copy, pill button back to safe screen.
- **settings_screen**: grouped list rows with icon badge, label, switch/chevron, account info and sign-out.
- **document_review_screen / omr_upload_screen**: dashed drop zone / camera-icon button, pending items as checklist rows with pill status tags.
- **timetable_grid_screen**: structured timetable grid with hairline dividers and role-accent color-blocked cells per subject.

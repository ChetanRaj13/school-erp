-- ============================================================================
-- 0014_invoice_line_items.sql
--
-- New table, built live this session to support the itemized fee-breakdown
-- feature requested from actual app testing (parent_fees_screen.dart). Apply
-- AFTER 0013_baseline_reconciliation.sql (depends on finance.invoices existing).
--
-- Context: only 2 finance.fee_structures exist (Tuition Fee, Transport Fee),
-- and one invoice could only ever reference ONE fee_structure_id — no way to
-- show a multi-line-item breakdown (Tuition/Admission/Exam/Library/etc. on one
-- invoice). This table makes that possible. It does NOT itself populate any
-- data — no fee-head amounts have been invented or backfilled for real
-- invoices. That's a deliberate product/data decision left for the Flutter/UI
-- build (see SESSION_LOG or context-handoff-brief for the corresponding Grok
-- prompt).
-- ============================================================================

create table if not exists finance.invoice_line_items (
  id                 uuid primary key default gen_random_uuid(),
  invoice_id         uuid not null references finance.invoices(id) on delete cascade,
  fee_structure_id   uuid references finance.fee_structures(id),
  label              text not null,
  amount             numeric(12,2) not null check (amount >= 0),
  sort_order         integer not null default 0,
  created_at         timestamptz not null default now()
);
create index idx_invoice_line_items_invoice_id on finance.invoice_line_items(invoice_id);

alter table finance.invoice_line_items enable row level security;

create policy admin_insert_invoice_line_items on finance.invoice_line_items
for insert
with check (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']));

create policy invoice_line_items_read on finance.invoice_line_items
for select
using (
  exists (
    select 1 from finance.invoices i
    join students s on s.id = i.student_id
    where i.id = invoice_line_items.invoice_id
      and (
        ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal'])
        or s.auth_user_id = auth.uid()
        or s.id in (select parent_links.student_id from parent_links where parent_links.parent_auth_user_id = auth.uid())
      )
  )
);

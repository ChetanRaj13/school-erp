-- ============================================================================
-- 0015_budget_audit_and_notes.sql
--
-- Adds budget audit trail tracking and budget notes support for advanced
-- budget module features as part of Prompt 6 (Budget Module Advanced Features).
-- This enables:
--   - Financial Audit Trail: Log all budget CRUD operations with user/timestamp/changes
--   - Budget History: View past budget states by fiscal year
--   - Budget Notes: Free-text notes per department per fiscal year
-- ============================================================================

-- ============================================================================
-- 1. Budget Audit Trail Table
-- Tracks every change to budgets table for audit/history purposes
-- ============================================================================

create table if not exists finance.budget_audit_trail (
  id                 uuid primary key default gen_random_uuid(),
  school_id          uuid not null references public.schools(id) on delete cascade,
  budget_id          uuid not null references finance.budgets(id) on delete cascade,
  operation_type     text not null check (operation_type = any (array['insert','update','delete'])),
  user_id            uuid not null references public.staff(id),
  old_data           jsonb,
  new_data           jsonb,
  changed_at         timestamptz not null default now(),
  ip_address         text
);

create index idx_budget_audit_trail_school_id on finance.budget_audit_trail(school_id);
create index idx_budget_audit_trail_budget_id on finance.budget_audit_trail(budget_id);
create index idx_budget_audit_trail_user_id on finance.budget_audit_trail(user_id);
create index idx_budget_audit_trail_changed_at on finance.budget_audit_trail(changed_at);
create index idx_budget_audit_trail_operation on finance.budget_audit_trail(operation_type);

alter table finance.budget_audit_trail enable row level security;

create policy admin_insert_budget_audit on finance.budget_audit_trail
for insert
with check (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']));

create policy budget_audit_read on finance.budget_audit_trail
for select
using (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']));

-- ============================================================================
-- 2. Budget Notes Table
-- Stores free-form notes per department per academic year for documentation
-- ============================================================================

create table if not exists finance.budget_notes (
  id                  uuid primary key default gen_random_uuid(),
  school_id           uuid not null references public.schools(id) on delete cascade,
  category            text not null,
  academic_year       text not null,
  notes               text,
  created_by          uuid not null references public.staff(id) on delete cascade,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (school_id, category, academic_year)
);

create index idx_budget_notes_school_id on finance.budget_notes(school_id);
create index idx_budget_notes_category on finance.budget_notes(category);
create index idx_budget_notes_academic_year on finance.budget_notes(academic_year);

alter table finance.budget_notes enable row level security;

create policy admin_insert_budget_notes on finance.budget_notes
for insert
with check (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']));

create policy budget_notes_read on finance.budget_notes
for select
using (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']));

create policy admin_update_budget_notes on finance.budget_notes
for update
using (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']))
with check (((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal']));

-- ============================================================================
-- 3. Trigger Function for Budget Audit Logging
-- Logs inserts, updates, and deletes to the budget_audit_trail table
-- ============================================================================

create or replace function finance.log_budget_change() returns trigger as $$
declare
  v_user_id uuid;
begin
  -- Get the user ID from the context (set via SET LOCAL in applications)
  -- This should be set by the application using SET INTO local
  -- If not set, try to get from auth.claims()
  begin
    v_user_id := current_setting('app.current_user_id', true)::uuid;
  exception
    when others then
      -- Fallback: try getting from JWT claims (edge functions can pass this)
      v_user_id := (auth.jwt() ->> 'user_id')::uuid;
  end raise notice;

  if TG_OP = 'INSERT' then
    insert into finance.budget_audit_trail (school_id, budget_id, operation_type, user_id, new_data, ip_address)
    values (
      NEW.school_id,
      NEW.id,
      'insert',
      coalesce(v_user_id, (select id from public.staff where email = (auth.jwt() ->> 'email'))),
      row(NEW.*::record)::jsonb,
      request_ip()
    );
    return NEW;
  elsif TG_OP = 'UPDATE' then
    insert into finance.budget_audit_trail (school_id, budget_id, operation_type, user_id, old_data, new_data, ip_address)
    values (
      OLD.school_id,
      OLD.id,
      'update',
      coalesce(v_user_id, (select id from public.staff where email = (auth.jwt() ->> 'email'))),
      row(OLD.*::record)::jsonb,
      row(NEW.*::record)::jsonb,
      request_ip()
    );
    return NEW;
  elsif TG_OP = 'DELETE' then
    insert into finance.budget_audit_trail (school_id, budget_id, operation_type, user_id, old_data, ip_address)
    values (
      OLD.school_id,
      OLD.id,
      'delete',
      coalesce(v_user_id, (select id from public.staff where email = (auth.jwt() ->> 'email'))),
      row(OLD.*::record)::jsonb,
      request_ip()
    );
    return OLD;
  end if;

  return null;
end;
$$ language plpgsql;

create trigger trg_budget_audit_after_insert
after insert on finance.budgets
for each row execute function finance.log_budget_change();

create trigger trg_budget_audit_after_update
after update on finance.budgets
for each row execute function finance.log_budget_change();

create trigger trg_budget_audit_after_delete
after delete on finance.budgets
for each row execute function finance.log_budget_change();
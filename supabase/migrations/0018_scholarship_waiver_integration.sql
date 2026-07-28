-- ============================================================================
-- 0018_scholarship_waiver_integration.sql
--
-- Properly integrates Scholarships & Waivers with the Fee Management system.
--
-- Problem: disbursement previously reduced amount_due (wrong) with no
-- validation, no payment record, and no audit trail. Scholarships could be
-- disbursed on already-paid invoices, and money had nowhere to go when no
-- invoice was linked.
--
-- Solution:
--   1. Add disbursed_amount, disbursed_by, notes columns to waiver_requests
--   2. Create finance.disburse_waiver() — atomic RPC that validates,
--      caps to outstanding balance, creates a payment record, and updates
--      the invoice's amount_paid (not amount_due).
-- ============================================================================


-- ============================================================================
-- 1. Schema additions to finance.waiver_requests
-- ============================================================================

-- disbursed_amount: the actual amount applied (may be < requested_amount if
-- the scholarship exceeded outstanding dues)
alter table finance.waiver_requests
  add column if not exists disbursed_amount numeric(12,2);

-- disbursed_by: which staff member performed the disbursement (audit trail)
alter table finance.waiver_requests
  add column if not exists disbursed_by uuid references public.staff(id);

-- notes: optional notes from the disburser
alter table finance.waiver_requests
  add column if not exists notes text;


-- ============================================================================
-- 2. finance.disburse_waiver() — atomic disbursement RPC
--
-- Flow:
--   a. Validate request exists, is approved, not yet disbursed
--   b. Validate invoice exists and has outstanding balance
--   c. Cap disbursement to outstanding (no negative balances)
--   d. Atomically: update invoice, insert payment, mark disbursed
--   e. Return result as jsonb
-- ============================================================================

create or replace function finance.disburse_waiver(
  p_request_id uuid,
  p_staff_id   uuid
)
returns jsonb
language plpgsql
security definer
set search_path = finance, public
as $$
declare
  v_request       finance.waiver_requests%rowtype;
  v_invoice       finance.invoices%rowtype;
  v_outstanding   numeric;
  v_actual_amount numeric;
  v_result        jsonb;
begin
  -- ── 1. Fetch the waiver request ──────────────────────────────────────────
  select * into v_request
  from finance.waiver_requests
  where id = p_request_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Waiver request not found.'
    );
  end if;

  -- ── 2. Validate: must be approved and not yet disbursed ──────────────────
  if v_request.status != 'approved' then
    return jsonb_build_object(
      'success', false,
      'message', 'Request must be approved before disbursement. Current status: ' || v_request.status || '.'
    );
  end if;

  if v_request.disbursed_at is not null then
    return jsonb_build_object(
      'success', false,
      'message', 'This request has already been disbursed on ' || v_request.disbursed_at::text || '.'
    );
  end if;

  -- ── 3. Validate: invoice must be linked ──────────────────────────────────
  if v_request.invoice_id is null then
    return jsonb_build_object(
      'success', false,
      'message', 'No invoice linked to this scholarship/waiver. Cannot disburse without a target invoice.'
    );
  end if;

  -- ── 4. Fetch the linked invoice ──────────────────────────────────────────
  select * into v_invoice
  from finance.invoices
  where id = v_request.invoice_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Linked invoice not found (may have been deleted).'
    );
  end if;

  -- ── 5. Calculate outstanding balance ─────────────────────────────────────
  v_outstanding := greatest(v_invoice.amount_due - v_invoice.amount_paid, 0);

  if v_outstanding <= 0 then
    return jsonb_build_object(
      'success', false,
      'message', 'Fees already fully paid. No outstanding balance to apply this scholarship/waiver against.'
    );
  end if;

  -- ── 6. Cap to outstanding — never create negative balances ───────────────
  v_actual_amount := least(v_request.requested_amount, v_outstanding);

  -- ── 7. Atomic updates ────────────────────────────────────────────────────
  -- 7a. Increase amount_paid on the invoice (NOT reduce amount_due)
  update finance.invoices
  set amount_paid = amount_paid + v_actual_amount
  where id = v_invoice.id;

  -- 7b. Create a payment record — this is what makes the disbursement appear
  --     in payment history and financial reports
  insert into finance.payments (
    invoice_id,
    amount,
    method,
    status,
    approved_by,
    reference_number,
    created_at
  ) values (
    v_invoice.id,
    v_actual_amount,
    v_request.request_type::public.payment_method,
    'success',
    p_staff_id,
    'WAIVER-' || substr(v_request.id::text, 1, 8),
    now()
  );

  -- 7c. Mark the waiver request as disbursed
  update finance.waiver_requests
  set disbursed_at     = now(),
      disbursed_amount = v_actual_amount,
      disbursed_by     = p_staff_id
  where id = v_request.id;

  -- ── 8. Build result ──────────────────────────────────────────────────────
  if v_actual_amount < v_request.requested_amount then
    v_result := jsonb_build_object(
      'success',         true,
      'disbursed_amount', v_actual_amount,
      'requested_amount', v_request.requested_amount,
      'message',         'Partial disbursement: ₹' || v_actual_amount::text ||
                         ' applied (requested ₹' || v_request.requested_amount::text ||
                         ', outstanding was ₹' || v_outstanding::text || ').'
    );
  else
    v_result := jsonb_build_object(
      'success',         true,
      'disbursed_amount', v_actual_amount,
      'requested_amount', v_request.requested_amount,
      'message',         'Full disbursement of ₹' || v_actual_amount::text || ' applied successfully.'
    );
  end if;

  return v_result;
end;
$$;

-- Grant execute to authenticated so the Flutter app can call this RPC
grant execute on function finance.disburse_waiver(uuid, uuid) to authenticated;

-- ============================================================================
-- 20260817001000_parent_online_payment_rpc.sql
--
-- Adds:
-- 1. Security definer RPC function finance.record_online_payment for atomic
--    recording of online payments and instant balance increment.
-- 2. Permissive RLS INSERT policy for parent/school isolation on finance.payments.
-- ============================================================================

create or replace function finance.record_online_payment(
  p_invoice_id uuid,
  p_amount numeric,
  p_method text,
  p_gateway_payment_id text,
  p_reference_number text
)
returns jsonb
language plpgsql
security definer
set search_path = finance, public
as $$
declare
  v_payment finance.payments%rowtype;
  v_school_id uuid;
begin
  -- Validate that the invoice exists
  select s.school_id into v_school_id
  from finance.invoices i
  join public.students s on s.id = i.student_id
  where i.id = p_invoice_id;

  if v_school_id is null then
    raise exception 'Invoice % not found', p_invoice_id;
  end if;

  -- Insert payment record atomically
  insert into finance.payments (
    invoice_id,
    amount,
    method,
    status,
    gateway_payment_id,
    reference_number
  ) values (
    p_invoice_id,
    p_amount,
    p_method,
    'success',
    p_gateway_payment_id,
    p_reference_number
  )
  returning * into v_payment;

  -- Atomically increment amount_paid on invoice
  update finance.invoices
  set amount_paid = amount_paid + p_amount
  where id = p_invoice_id;

  return jsonb_build_object(
    'id', v_payment.id,
    'invoice_id', v_payment.invoice_id,
    'amount', v_payment.amount,
    'method', v_payment.method,
    'status', v_payment.status,
    'gateway_payment_id', v_payment.gateway_payment_id,
    'reference_number', v_payment.reference_number,
    'created_at', v_payment.created_at
  );
end;
$$;

grant execute on function finance.record_online_payment(uuid, numeric, text, text, text) to authenticated;

drop policy if exists parent_insert_payments on finance.payments;
create policy parent_insert_payments on finance.payments
for insert
with check (
  exists (
    select 1 from finance.invoices i
    join students s on s.id = i.student_id
    where i.id = payments.invoice_id
      and s.school_id = (((auth.jwt() -> 'app_metadata'::text) ->> 'school_id'::text))::uuid
  )
);

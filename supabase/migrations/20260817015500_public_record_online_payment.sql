-- ============================================================================
-- 20260817015500_public_record_online_payment.sql
--
-- Exposes record_online_payment in the public schema for Supabase PostgREST RPC.
-- Atomically inserts the payment into finance.payments and increments
-- finance.invoices.amount_paid.
-- ============================================================================

create or replace function public.record_online_payment(
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

grant execute on function public.record_online_payment(uuid, numeric, text, text, text) to authenticated;
grant execute on function public.record_online_payment(uuid, numeric, text, text, text) to anon;
grant execute on function public.record_online_payment(uuid, numeric, text, text, text) to service_role;

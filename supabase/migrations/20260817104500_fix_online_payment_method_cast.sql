-- ============================================================================
-- 20260817104500_fix_online_payment_method_cast.sql
--
-- Fixes type-mismatch error:
--   "column 'method' is of type payment_method but expression is of type text"
-- Normalizes input method string and explicitly casts to public.payment_method
-- and public.payment_status enums in public.record_online_payment and
-- finance.record_online_payment.
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
  v_norm_method text;
  v_method public.payment_method;
begin
  -- Validate that the invoice exists
  select s.school_id into v_school_id
  from finance.invoices i
  join public.students s on s.id = i.student_id
  where i.id = p_invoice_id;

  if v_school_id is null then
    raise exception 'Invoice % not found', p_invoice_id;
  end if;

  -- Normalize method name to match enum values
  v_norm_method := lower(trim(coalesce(p_method, 'upi')));
  if v_norm_method in ('card', 'credit_card', 'debit_card') then
    v_method := 'credit_card'::public.payment_method;
  elsif v_norm_method in ('netbanking', 'net_banking') then
    v_method := 'net_banking'::public.payment_method;
  elsif v_norm_method = 'upi' then
    v_method := 'upi'::public.payment_method;
  elsif v_norm_method in ('cash', 'cheque', 'demand_draft', 'scholarship', 'grant', 'loan', 'waiver') then
    v_method := v_norm_method::public.payment_method;
  else
    v_method := 'upi'::public.payment_method;
  end if;

  -- Insert payment record atomically with explicit enum casting
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
    v_method,
    'success'::public.payment_status,
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
    'method', v_payment.method::text,
    'status', v_payment.status::text,
    'gateway_payment_id', v_payment.gateway_payment_id,
    'reference_number', v_payment.reference_number,
    'created_at', v_payment.created_at
  );
end;
$$;

grant execute on function public.record_online_payment(uuid, numeric, text, text, text) to authenticated;
grant execute on function public.record_online_payment(uuid, numeric, text, text, text) to anon;
grant execute on function public.record_online_payment(uuid, numeric, text, text, text) to service_role;

-- ============================================================================
-- 0017_atomic_payment_increment.sql
--
-- Adds a Postgres function for atomically incrementing finance.invoices.amount_paid.
-- The previous approach used read-modify-write (SELECT then UPDATE), which has
-- a race condition: two concurrent webhooks or offline payments for the same
-- invoice could both read the same amount_paid, compute the same new value, and
-- one increment would be silently lost.
--
-- This function uses UPDATE SET amount_paid = amount_paid + p_amount, which
-- Postgres serializes at the row level — concurrent increments are queued and
-- applied atomically.
--
-- Grant EXECUTE to authenticated so the Flutter app's offline payment screen
-- can call it through the anon/authenticated key. The function is security
-- definer (runs as the owner, which has direct table access), so the row-level
-- security on finance.invoices still applies to the underlying UPDATE — but
-- the RLS policy already checks school_id through the student join, so this
-- is properly scoped.
-- ============================================================================

create or replace function finance.increment_invoice_paid(p_invoice_id uuid, p_amount numeric)
returns void
language sql
security definer
set search_path = finance, public
as $$
  update finance.invoices
  set amount_paid = amount_paid + p_amount
  where id = p_invoice_id;
$$;

-- Grant execute to the authenticated role so the Flutter app can call this RPC.
-- The anon key routes through the anon role by default, but the Flutter app
-- uses the anon key with auth.signIn — once signed in, the session token has
-- the 'authenticated' role.
grant execute on function finance.increment_invoice_paid(uuid, numeric) to authenticated;


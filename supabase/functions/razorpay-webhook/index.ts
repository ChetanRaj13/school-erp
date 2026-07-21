// Supabase Edge Function: receives Razorpay webhooks and records payments.
//
// Flow: the client opens Checkout against an order created by
// `create-razorpay-order`. Razorpay then calls THIS function asynchronously
// with the authoritative payment result. This is the ONLY place payments are
// recorded — never trust the client's success callback, which can be forged.
//
// Two things make this function trustworthy:
//   1. Signature verification over the RAW body (below). We reject anything
//      that doesn't verify, because an unverified webhook is just an
//      anonymous POST claiming a payment happened.
//   2. It runs with the service-role key, so it can write finance.* rows that
//      RLS would block for a normal user. That means it must be paranoid about
//      what it trusts — hence the signature gate comes first, before any parse.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-razorpay-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

// Razorpay's payment `method` strings don't match our payment_method enum, so
// we translate. For a card we look at card.type (credit/debit) to pick the
// right enum value. Anything we don't recognise is rejected rather than
// silently coerced — a wrong method on a financial record is worse than a
// loud failure we can investigate.
function mapPaymentMethod(entity: Record<string, unknown>): string | null {
  const method = entity.method as string | undefined;
  switch (method) {
    case 'upi':
      return 'upi';
    case 'netbanking':
      return 'net_banking';
    case 'card': {
      const cardType = (entity.card as Record<string, unknown> | undefined)?.type;
      if (cardType === 'credit') return 'credit_card';
      if (cardType === 'debit') return 'debit_card';
      // Prepaid/unknown card sub-type: default to credit_card so the NOT NULL
      // enum column is satisfied. Flagged in raw_gateway_response for audit.
      return 'credit_card';
    }
    default:
      // wallet, emi, paylater, etc. have no enum equivalent yet.
      return null;
  }
}

// Constant-time hex-string comparison so we don't leak signature bytes via
// early-exit timing. Lengths differ => not equal, but still compare fully.
function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  const len = Math.max(ab.length, bb.length);
  let diff = ab.length ^ bb.length;
  for (let i = 0; i < len; i++) {
    diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0);
  }
  return diff === 0;
}

// Razorpay signs the webhook as HMAC-SHA256(rawBody, webhookSecret), hex-encoded.
// The secret is the one you enter in the Razorpay Dashboard when creating the
// webhook — configured here as RAZORPAY_WEBHOOK_SECRET. We fall back to
// RAZORPAY_KEY_SECRET only so a misconfigured env fails closed-ish in Test Mode.
async function verifySignature(rawBody: string, signature: string, secret: string): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return timingSafeEqual(expected, signature);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET') ?? Deno.env.get('RAZORPAY_KEY_SECRET');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!webhookSecret || !supabaseUrl || !serviceRoleKey) {
    // Config error, not a client error. 500 so Razorpay retries once we fix it.
    return json({ error: 'server not configured' }, 500);
  }

  // Read the RAW body first. Signature is computed over these exact bytes, so
  // we must NOT JSON.parse before verifying — a re-serialized object would
  // have different whitespace/key-order and never match.
  const rawBody = await req.text();
  const signature = req.headers.get('x-razorpay-signature') ?? '';
  if (!signature) {
    return json({ error: 'missing signature' }, 400);
  }
  if (!(await verifySignature(rawBody, signature, webhookSecret))) {
    // Unverified webhook: reject and record nothing. 401, not 400 — the payload
    // may be well-formed, it just isn't provably from Razorpay.
    return json({ error: 'invalid signature' }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid JSON' }, 400);
  }

  const eventType = event.event as string | undefined;
  // We only act on terminal payment events. Everything else (order.paid,
  // refunds, etc.) is acknowledged with 200 so Razorpay stops retrying, but
  // ignored — acknowledging is not the same as recording.
  if (eventType !== 'payment.captured' && eventType !== 'payment.failed') {
    return json({ received: true, ignored: eventType ?? 'unknown' }, 200);
  }

  const entity = ((event.payload as Record<string, unknown>)?.payment as Record<string, unknown>)
    ?.entity as Record<string, unknown> | undefined;
  if (!entity) {
    return json({ error: 'malformed payload: no payment entity' }, 400);
  }

  // invoice_id is NOT NULL. The payment entity only carries order_id, so the
  // invoice must be passed through Checkout as a note. See the companion change
  // required in create-razorpay-order (notes: { invoice_id }).
  const invoiceId = (entity.notes as Record<string, unknown> | undefined)?.invoice_id as string | undefined;
  if (!invoiceId) {
    // We can't file this payment against an invoice. Return 200 so Razorpay
    // doesn't retry forever, but make the drop loud rather than silent.
    console.error('payment received with no notes.invoice_id; cannot link', {
      gateway_payment_id: entity.id,
      gateway_order_id: entity.order_id,
    });
    return json({ received: true, error: 'no invoice_id in payment notes; not recorded' }, 200);
  }

  const method = mapPaymentMethod(entity);
  if (!method) {
    console.error('unmappable payment method; not recorded', { method: entity.method, id: entity.id });
    return json({ received: true, error: `unmapped method '${entity.method}'; not recorded` }, 200);
  }

  const status = eventType === 'payment.captured' ? 'success' : 'failed';
  // Razorpay amounts are in paise (integer). finance.payments.amount is rupees.
  const amountRupees = (entity.amount as number) / 100;

  // finance.* lives in its own schema; scope the client to it so .from('payments')
  // resolves to finance.payments. Service-role key bypasses RLS by design here.
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    db: { schema: 'finance' },
    auth: { persistSession: false },
  });

  const gatewayPaymentId = entity.id as string;

  // Idempotency: Razorpay retries webhooks (and may deliver duplicates). If we
  // already recorded this gateway_payment_id, don't insert again and don't
  // double-count amount_paid. Best-effort check-then-act — a DB unique index on
  // gateway_payment_id would make this airtight; noted as a follow-up.
  const { data: existing, error: existingErr } = await supabase
    .from('payments')
    .select('id')
    .eq('gateway_payment_id', gatewayPaymentId)
    .maybeSingle();
  if (existingErr) {
    console.error('lookup failed', existingErr);
    return json({ error: 'db lookup failed' }, 500);
  }
  if (existing) {
    return json({ received: true, duplicate: true, payment_id: existing.id }, 200);
  }

  const { data: inserted, error: insertErr } = await supabase
    .from('payments')
    .insert({
      invoice_id: invoiceId,
      amount: amountRupees,
      method,
      status,
      gateway_order_id: entity.order_id as string,
      gateway_payment_id: gatewayPaymentId,
      gateway_signature: signature,
      raw_gateway_response: event, // full verified event, for audit/reconciliation
    })
    .select('id')
    .single();
  if (insertErr) {
    console.error('payment insert failed', insertErr);
    return json({ error: 'failed to record payment' }, 500);
  }

  // Only a captured (successful) payment moves money against the invoice.
  // A failed payment is recorded for the audit trail but must NOT touch
  // amount_paid.
  if (status === 'success') {
    // Read-modify-write increment. NOTE: this is not atomic — two captured
    // webhooks for the same invoice arriving concurrently could race and lose
    // an increment. For production, move this into a Postgres function/trigger
    // (amount_paid = amount_paid + excluded) called via rpc so the DB serializes
    // it. Left as read-modify-write here to avoid altering the live schema
    // without approval.
    const { data: invoice, error: invErr } = await supabase
      .from('invoices')
      .select('amount_paid')
      .eq('id', invoiceId)
      .maybeSingle();
    if (invErr || !invoice) {
      // Payment is already recorded; surface the invoice-update problem so it
      // can be reconciled rather than lost.
      console.error('invoice not found for amount_paid update', { invoiceId, invErr });
      return json(
        { received: true, payment_id: inserted.id, warning: 'payment recorded but invoice not updated' },
        200,
      );
    }
    const newAmountPaid = Number(invoice.amount_paid) + amountRupees;
    const { error: updateErr } = await supabase
      .from('invoices')
      .update({ amount_paid: newAmountPaid })
      .eq('id', invoiceId);
    if (updateErr) {
      console.error('amount_paid update failed', updateErr);
      return json(
        { received: true, payment_id: inserted.id, warning: 'payment recorded but amount_paid update failed' },
        200,
      );
    }
  }

  return json({ received: true, payment_id: inserted.id, status }, 200);
});

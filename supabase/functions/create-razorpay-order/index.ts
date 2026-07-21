// Supabase Edge Function: creates a Razorpay order for a fee invoice.
// Called by the Flutter app before opening Razorpay Checkout (Test Mode).
// The returned order.id is handed to the client SDK; payment confirmation
// arrives asynchronously via the razorpay-webhook function, which is what
// actually writes finance.transactions. This function only opens the order.

// Allow calls from the Flutter web build. Tighten the origin before production.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const json = (body: unknown, status: number) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  const { invoice_id, amount } = await req.json();

  // Validate before hitting Razorpay — amount is in rupees, must be positive.
  if (!invoice_id || typeof amount !== 'number' || amount <= 0) {
    return json({ error: 'invoice_id and a positive numeric amount are required' }, 400);
  }

  const keyId = Deno.env.get('RAZORPAY_KEY_ID');
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
  if (!keyId || !keySecret) {
    return json({ error: 'Razorpay keys not configured' }, 500);
  }

  const auth = btoa(`${keyId}:${keySecret}`);

  const res = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: Math.round(amount * 100), // paise; round to avoid float drift (e.g. 199.99 * 100)
      currency: 'INR',
      receipt: invoice_id,
    }),
  });

  const order = await res.json();
  // Propagate Razorpay's status so the client can distinguish success from failure.
  return json(order, res.status);
});

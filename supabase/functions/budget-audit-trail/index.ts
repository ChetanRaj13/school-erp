// Supabase Edge Function: logs changes to the budget audit trail table.
// This is called from the Flutter app when creating/updating/deleting budgets via HTTP API,
// ensuring audit logging even when database triggers aren't sufficient (e.g., bulk operations).
// Also used for manual audit trail entries from other services.

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

  const { budgetId, operationType, schoolId, oldValue, newValue, userId, ipAddress } = await req.json();

  // Validate required fields
  if (!budgetId || !operationType || !['insert', 'update', 'delete'].includes(operationType)) {
    return json({ error: 'Valid budgetId and operationType (insert/update/delete) are required' }, 400);
  }

  if (!userId) {
    return json({ error: 'userId is required' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseServiceKey) {
    return json({ error: 'Supabase credentials not configured' }, 500);
  }

  try {
    const response = await fetch(`${supabaseUrl}/rpc/budget_audit_log`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'apikey': supabaseServiceKey,
      },
      body: JSON.stringify({
        budget_id: budgetId,
        operation_type: operationType,
        school_id: schoolId,
        old_value: oldValue,
        new_value: newValue,
        user_id: userId,
        ip_address: ipAddress || req.headers.get('x-forward-for') || 'unknown',
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      return json({ error: `Failed to log audit trail: ${result.message || result.error || 'Unknown error'}` }, 500);
    }

    return json({ success: true, data: result }, 201);
  } catch (error) {
    return json({ error: `Internal server error: ${error instanceof Error ? error.message : String(error)}` }, 500);
  }
});

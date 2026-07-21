// Optional: post-processing after an attendance.records insert (e.g. push
// notification to parent app). Realtime sync itself is handled natively by
// Supabase Realtime + Riverpod StreamProvider on the client — this function
// is only for side effects (notifications), not the sync itself.

Deno.serve(async (req) => {
  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});

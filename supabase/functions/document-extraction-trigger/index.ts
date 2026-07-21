// Triggered on new upload to the admission-forms storage bucket.
// Calls the document-extraction microservice, writes the returned JSON
// into documents.admission_forms with status 'pending_review'.

Deno.serve(async (req) => {
  const { imageUrl, studentId } = await req.json();
  // TODO: call services/document-extraction, then insert into documents.admission_forms
  return new Response(JSON.stringify({ queued: true }), { status: 200 });
});

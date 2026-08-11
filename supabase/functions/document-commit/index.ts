// Persists admin-reviewed admission-form fields to public.students.
// Ported from services/document-extraction/main.py's POST /documents/commit,
// so this feature never needs a separately-run Python server.
// Human-in-the-loop: only fields explicitly provided in the request body are
// written — nothing here re-runs extraction or trusts the AI draft directly.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const DEMO_SCHOOL_ID = '11111111-1111-1111-1111-111111111111';

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.json();
    const { form_id, full_name, admission_number, guardian_contact, student_id } = body;

    if (!form_id) {
      return new Response(JSON.stringify({ error: 'form_id is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Verify form exists and is still pending review
    const { data: form, error: formErr } = await supabase
      .schema('documents')
      .from('admission_forms')
      .select('*')
      .eq('id', form_id)
      .single();

    if (formErr || !form) {
      return new Response(JSON.stringify({ error: `form_id ${form_id} not found.` }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (form.status !== 'pending_review') {
      return new Response(
        JSON.stringify({ error: `Form already ${form.status} — cannot re-commit.` }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const studentPayload: Record<string, string> = {};
    if (full_name != null) studentPayload.full_name = full_name;
    if (admission_number != null) studentPayload.admission_number = admission_number;
    if (guardian_contact != null) studentPayload.guardian_contact = guardian_contact;

    if (Object.keys(studentPayload).length === 0) {
      return new Response(
        JSON.stringify({ error: 'At least one of full_name, admission_number, guardian_contact required.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const reviewedAt = new Date().toISOString();
    let resolvedStudentId: string;

    if (student_id) {
      const { data: updated, error: updErr } = await supabase
        .from('students')
        .update(studentPayload)
        .eq('id', student_id)
        .select()
        .single();
      if (updErr || !updated) {
        return new Response(
          JSON.stringify({ error: `Student update failed: ${updErr?.message ?? 'not found'}` }),
          { status: updErr ? 500 : 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      resolvedStudentId = student_id;
    } else {
      if (!studentPayload.full_name || !studentPayload.admission_number) {
        return new Response(
          JSON.stringify({ error: 'full_name and admission_number required to create a new student.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      const { data: inserted, error: insErr } = await supabase
        .from('students')
        .insert({ ...studentPayload, school_id: DEMO_SCHOOL_ID })
        .select()
        .single();
      if (insErr || !inserted) {
        return new Response(
          JSON.stringify({ error: `Student insert failed: ${insErr?.message}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      resolvedStudentId = inserted.id;
    }

    await supabase
      .schema('documents')
      .from('admission_forms')
      .update({ status: 'verified', student_id: resolvedStudentId, reviewed_at: reviewedAt })
      .eq('id', form_id);

    return new Response(
      JSON.stringify({ status: 'committed', student_id: resolvedStudentId, form_id, reviewed_at: reviewedAt }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

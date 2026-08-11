// Vision-LLM extraction via OpenRouter — ported from services/document-extraction/
// (extractor.py + main.py's /documents/extract), so this feature never needs a
// separately-run Python server. Never writes to public.students directly —
// stores a draft in documents.admission_forms with status='pending_review';
// see the companion `document-commit` function for the human-reviewed write.
//
// v2: accepts JSON (base64 image) instead of multipart/form-data, matching
// the same calling convention already proven working for document-commit via
// the Supabase Flutter SDK's client.functions.invoke().

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MODEL = 'nvidia/nemotron-nano-12b-v2-vl:free';
const FALLBACK_MODEL = 'google/gemma-4-26b-a4b-it:free';

const EXTRACTION_PROMPT = `You are extracting fields from a school admission form image.
Return ONLY a JSON object with this exact structure — no markdown, no explanation:
{
  "fields": {
    "full_name": {"value": "...", "confidence": 0.0-1.0},
    "admission_number": {"value": "...", "confidence": 0.0-1.0},
    "guardian_contact": {"value": "...", "confidence": 0.0-1.0},
    "dob": {"value": "...", "confidence": 0.0-1.0},
    "guardian_name": {"value": "...", "confidence": 0.0-1.0},
    "address": {"value": "...", "confidence": 0.0-1.0},
    "previous_school": {"value": "...", "confidence": 0.0-1.0}
  }
}
Rules:
- Set value to null if the field is absent or illegible.
- Set confidence < 0.7 for handwritten, smudged, or ambiguous text.
- guardian_contact must be a phone number if present.
- Return only the JSON object, nothing else.`;

async function callOpenRouter(imageB64: string, mimeType: string, model: string, apiKey: string) {
  const resp = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: EXTRACTION_PROMPT },
            { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageB64}` } },
          ],
        },
      ],
      max_tokens: 512,
    }),
  });
  if (!resp.ok) {
    const err = new Error(`OpenRouter HTTP ${resp.status}`);
    (err as any).status = resp.status;
    throw err;
  }
  return resp.json();
}

function parseModelJson(content: string): any {
  let text = content.trim();
  if (text.startsWith('```')) {
    const parts = text.split('```');
    text = parts[1] ?? text;
    if (text.startsWith('json')) text = text.slice(4);
  }
  return JSON.parse(text);
}

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const apiKey = Deno.env.get('OPENROUTER_API_KEY');
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'OPENROUTER_API_KEY not configured' }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // JSON body now, matching document-commit's calling convention:
    // { file_base64: string (no data: prefix), mime_type: string, file_name?: string }
    const body = await req.json();
    const { file_base64, mime_type, file_name } = body;
    if (!file_base64 || !mime_type) {
      return new Response(
        JSON.stringify({ error: 'file_base64 and mime_type are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    let raw: any;
    let modelUsed = MODEL;
    try {
      raw = await callOpenRouter(file_base64, mime_type, MODEL, apiKey);
    } catch (e: any) {
      if ([400, 404, 429].includes(e.status)) {
        raw = await callOpenRouter(file_base64, mime_type, FALLBACK_MODEL, apiKey);
        modelUsed = FALLBACK_MODEL;
      } else {
        throw e;
      }
    }

    const content = raw.choices[0].message.content;
    const parsed = parseModelJson(content);
    const fields = parsed.fields ?? {};
    const uncertainFields = Object.entries(fields)
      .filter(([, v]: [string, any]) => v && (v.confidence ?? 1.0) < 0.7)
      .map(([k]) => k);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: inserted, error } = await supabase
      .schema('documents')
      .from('admission_forms')
      .insert({
        original_image_url: file_name || 'uploaded',
        extracted_json: fields,
        uncertain_fields: uncertainFields,
        status: 'pending_review',
        extracted_by: modelUsed,
      })
      .select()
      .single();

    if (error) {
      return new Response(JSON.stringify({ error: `Failed to store draft: ${error.message}` }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({
        form_id: inserted.id,
        fields,
        uncertain_fields: uncertainFields,
        model_used: modelUsed,
        status: 'pending_review',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e: any) {
    return new Response(JSON.stringify({ error: `LLM extraction failed: ${e.message}` }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

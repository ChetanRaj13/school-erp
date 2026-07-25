"""
Vision-LLM extraction via OpenRouter (OpenAI-compatible).
Returns extracted fields + uncertain_fields list.
Never writes to DB — caller handles human-review step (AGENTS.md hard rule).
"""
import os
import json
import base64
import httpx

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "nvidia/nemotron-nano-12b-v2-vl:free"
FALLBACK_MODEL = "google/gemma-4-26b-a4b-it:free"

EXTRACTION_PROMPT = """You are extracting fields from a school admission form image.
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
- Return only the JSON object, nothing else."""


def _call_openrouter(image_b64: str, mime_type: str, model: str) -> dict:
    api_key = os.environ.get("OPENROUTER_API_KEY", "")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": EXTRACTION_PROMPT},
                    {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{image_b64}"}},
                ],
            }
        ],
        "max_tokens": 512,
    }
    resp = httpx.post(OPENROUTER_URL, json=payload, headers=headers, timeout=60)
    resp.raise_for_status()
    return resp.json()


def extract_fields(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
    """
    Send image to Vision-LLM, parse structured JSON response.
    Returns {"fields": {...}, "uncertain_fields": [...], "model_used": "..."}.
    Raises on network/parse failure.
    """
    if not os.environ.get("OPENROUTER_API_KEY"):
        raise RuntimeError("OPENROUTER_API_KEY not set")

    image_b64 = base64.b64encode(image_bytes).decode()

    try:
        raw = _call_openrouter(image_b64, mime_type, MODEL)
        model_used = MODEL
    except httpx.HTTPStatusError as e:
        if e.response.status_code in (400, 404, 429):
            raw = _call_openrouter(image_b64, mime_type, FALLBACK_MODEL)
            model_used = FALLBACK_MODEL
        else:
            raise

    content = raw["choices"][0]["message"]["content"].strip()
    # Strip markdown code fences if model wrapped the JSON
    if content.startswith("```"):
        content = content.split("```")[1]
        if content.startswith("json"):
            content = content[4:]
    parsed = json.loads(content)

    fields = parsed.get("fields", {})
    uncertain = [k for k, v in fields.items() if v and v.get("confidence", 1.0) < 0.7]

    return {"fields": fields, "uncertain_fields": uncertain, "model_used": model_used}

"""FastAPI wrapper around Vision-LLM structured extraction.
POST /extract with an image URL -> returns structured JSON fields +
uncertain_fields list. This is direct vision-LLM extraction, NOT RAG
(see AGENTS.md) — no vector store, no retrieval step.
"""
from fastapi import FastAPI
# from extractor import extract_fields

app = FastAPI(title="Document Extraction Service")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/extract")
def extract(payload: dict):
    # TODO: call extract_fields(payload["image_url"]) from extractor.py
    return {"status": "not_implemented"}

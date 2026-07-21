"""
Sends the form image to a vision-capable LLM with a structured-JSON prompt.
Never auto-save extracted fields directly to the DB from here — always return
them to the caller for the human-review step (see AGENTS.md hard rules).
"""


def extract_fields(image_url: str) -> dict:
    # TODO: call the LLM API, parse JSON response, return
    # { "fields": {...}, "uncertain_fields": [...] }
    raise NotImplementedError

# services/document-extraction/Dockerfile
# NOT built or run from here. Run `docker build -t document-extraction .` from inside
# services/document-extraction/ and verify.
#
# ⚠️ PORT FLAG — worth checking before finalizing this file: SESSION_LOG.md's most
# recent entry shows this service being started on port 8003 during the E2E test
# ("Port 8003 is occupied by PID 13376 — killing it first" then starting fresh) — the
# SAME port timetable-solver uses. That's fine if you only ever run one service at a
# time locally, but it's a real conflict for docker-compose or any setup running
# multiple services together. Confirm the actual --port value in how this service is
# started (check main.py / any run script) and change EXPOSE below to match, or
# reassign this service to a free port (8005 suggested, since 8003/8004 are taken by
# timetable-solver/predictive-engine).
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# OPENROUTER_API_KEY passed at `docker run` time via --env-file, never baked into the image.
EXPOSE 8003
# TODO verify the real port and update both EXPOSE and CMD below to match.

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]

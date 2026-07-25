# services/timetable-solver/Dockerfile
# NOT built or run from here — no Docker access in this environment. Agent should run
# `docker build -t timetable-solver .` from inside services/timetable-solver/ and fix
# whatever surfaces (this is a first-pass Dockerfile, standard FastAPI pattern, but
# genuinely untested).
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / etc. are NOT baked into the image —
# pass them at `docker run` time via --env-file or -e, same secrets discipline as
# every .env file already in this project (never commit real keys into an image layer).
EXPOSE 8003

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]

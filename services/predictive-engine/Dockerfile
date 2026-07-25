# services/predictive-engine/Dockerfile
# NOT built or run from here. Run `docker build -t predictive-engine .` from inside
# services/predictive-engine/ and verify.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# NOTE: this image includes scripts/seed_synthetic_absences.py and
# cleanup_synthetic_absences.py — harmless to ship (they require an explicit CLI
# invocation to do anything), but if you'd rather keep the image lean, add a
# .dockerignore excluding scripts/ before building for an actual deployment.
EXPOSE 8004

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8004"]

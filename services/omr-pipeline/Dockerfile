# services/omr-pipeline/Dockerfile
# NOT built or run from here, and MORE UNVERIFIED than the other three Dockerfiles in
# this batch — I don't have this service's actual main.py content, only that it's a
# FastAPI service with generate_omr.py / scan_omr.py / test_pipeline.py per earlier
# session context. Confirm the entrypoint filename and port before trusting this file;
# adjust CMD if the app object isn't literally `main:app`, and adjust EXPOSE to
# port 8002 (matching main.py docstring).
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# OpenCV (used for ArUco marker detection per AGENTS.md) often needs extra system
# libraries beyond pip install alone in a slim image — if `docker build` fails on an
# opencv import error, add:
#   RUN apt-get update && apt-get install -y libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*
# above the pip install line.

COPY . .

EXPOSE 8002

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002"]

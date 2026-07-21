"""FastAPI wrapper around the OR-Tools CP-SAT timetable solver.
POST /generate with constraints -> returns a clash-free timetable or
a 422 with the specific conflicting constraints (never fail silently).
"""
from fastapi import FastAPI
# from solver import solve_timetable

app = FastAPI(title="Timetable Solver Service")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/generate")
def generate_timetable(payload: dict):
    # TODO: call solve_timetable(payload) from solver.py
    return {"status": "not_implemented"}

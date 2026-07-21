"""FastAPI wrapper for absence/substitute-demand forecasting.
Pulls historical attendance.records + scheduling.substitutions data,
returns a simple day-of-week / seasonal risk score — kept explainable
on purpose (see AGENTS.md: transparent stats over black-box ML)."""
from fastapi import FastAPI
# from forecast import forecast_absence_risk

app = FastAPI(title="Predictive Resource Allocation Service")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/forecast")
def forecast():
    # TODO: call forecast_absence_risk() from forecast.py
    return {"status": "not_implemented"}

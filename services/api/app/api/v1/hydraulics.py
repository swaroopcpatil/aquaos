"""Hydraulic calculation endpoint. Deterministic; no AI involved."""

from fastapi import APIRouter

from app.engineering import HydraulicInput, HydraulicResult, calculate

router = APIRouter(prefix="/hydraulics", tags=["hydraulics"])


@router.post("/calculate", response_model=HydraulicResult)
def calculate_hydraulics(payload: HydraulicInput) -> HydraulicResult:
    return calculate(payload)

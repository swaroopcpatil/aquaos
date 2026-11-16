"""Deterministic hydraulic calculations for AquaOS.

Nothing in this package calls an AI model or performs I/O. Identical inputs
always produce identical outputs.
"""

from app.engineering.calculator import METHODOLOGY_VERSION, calculate
from app.engineering.models import HydraulicInput, HydraulicResult

__all__ = ["METHODOLOGY_VERSION", "HydraulicInput", "HydraulicResult", "calculate"]

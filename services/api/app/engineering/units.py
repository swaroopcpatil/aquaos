"""Explicit unit conversions. The engine works in SI; these are the only entry and exit points."""

from enum import StrEnum

from app.engineering.constants import KILOWATTS_PER_HP

SECONDS_PER_HOUR = 3600.0
SECONDS_PER_MINUTE = 60.0
LITRES_PER_M3 = 1000.0
MM_PER_M = 1000.0


class FlowUnit(StrEnum):
    M3_PER_H = "m3_per_h"
    L_PER_MIN = "l_per_min"
    L_PER_S = "l_per_s"
    M3_PER_S = "m3_per_s"


def flow_to_m3_per_s(value: float, unit: FlowUnit) -> float:
    if unit is FlowUnit.M3_PER_S:
        return value
    if unit is FlowUnit.M3_PER_H:
        return value / SECONDS_PER_HOUR
    if unit is FlowUnit.L_PER_S:
        return value / LITRES_PER_M3
    if unit is FlowUnit.L_PER_MIN:
        return value / LITRES_PER_M3 / SECONDS_PER_MINUTE
    raise ValueError(f"Unsupported flow unit: {unit!r}")


def m3_per_s_to_m3_per_h(value: float) -> float:
    return value * SECONDS_PER_HOUR


def m3_per_s_to_l_per_s(value: float) -> float:
    return value * LITRES_PER_M3


def m3_per_s_to_l_per_min(value: float) -> float:
    return value * LITRES_PER_M3 * SECONDS_PER_MINUTE


def mm_to_m(value: float) -> float:
    return value / MM_PER_M


def kw_to_hp(value: float) -> float:
    return value / KILOWATTS_PER_HP

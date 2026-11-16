"""Pipe friction by Darcy-Weisbach with the Swamee-Jain friction factor."""

import math

from app.engineering.constants import (
    GRAVITY_M_S2,
    LAMINAR_REYNOLDS_LIMIT,
    TURBULENT_REYNOLDS_LIMIT,
    WATER_KINEMATIC_VISCOSITY_M2_S,
)


def flow_velocity_m_s(flow_m3_s: float, diameter_m: float) -> float:
    if diameter_m <= 0:
        raise ValueError("Pipe diameter must be greater than zero.")
    return flow_m3_s / (math.pi * diameter_m**2 / 4.0)


def reynolds_number(
    velocity_m_s: float,
    diameter_m: float,
    kinematic_viscosity_m2_s: float = WATER_KINEMATIC_VISCOSITY_M2_S,
) -> float:
    return velocity_m_s * diameter_m / kinematic_viscosity_m2_s


def flow_regime(reynolds: float) -> str:
    if reynolds < LAMINAR_REYNOLDS_LIMIT:
        return "laminar"
    if reynolds < TURBULENT_REYNOLDS_LIMIT:
        return "transitional"
    return "turbulent"


def _laminar_factor(reynolds: float) -> float:
    return 64.0 / reynolds


def _swamee_jain_factor(reynolds: float, relative_roughness: float) -> float:
    return 0.25 / math.log10(relative_roughness / 3.7 + 5.74 / reynolds**0.9) ** 2


def darcy_friction_factor(reynolds: float, relative_roughness: float) -> float:
    """Darcy friction factor.

    Laminar: 64/Re. Turbulent: Swamee-Jain. Between the two limits the factor is
    interpolated linearly so the function is continuous; real transitional flow is
    unstable and the value there is an estimate.
    """
    if reynolds <= 0:
        raise ValueError("Reynolds number must be greater than zero.")
    if relative_roughness < 0:
        raise ValueError("Relative roughness cannot be negative.")
    if reynolds < LAMINAR_REYNOLDS_LIMIT:
        return _laminar_factor(reynolds)
    if reynolds >= TURBULENT_REYNOLDS_LIMIT:
        return _swamee_jain_factor(reynolds, relative_roughness)
    low = _laminar_factor(LAMINAR_REYNOLDS_LIMIT)
    high = _swamee_jain_factor(TURBULENT_REYNOLDS_LIMIT, relative_roughness)
    share = (reynolds - LAMINAR_REYNOLDS_LIMIT) / (
        TURBULENT_REYNOLDS_LIMIT - LAMINAR_REYNOLDS_LIMIT
    )
    return low + share * (high - low)


def friction_head_loss_m(
    friction_factor: float, length_m: float, diameter_m: float, velocity_m_s: float
) -> float:
    """Darcy-Weisbach: h_f = f * (L / D) * v^2 / (2 g)."""
    return friction_factor * (length_m / diameter_m) * velocity_m_s**2 / (2.0 * GRAVITY_M_S2)

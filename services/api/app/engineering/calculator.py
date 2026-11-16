"""Total dynamic head and power for a borewell pumping system.

Pure functions only. See docs/architecture/HYDRAULIC_METHODOLOGY.md.
"""

from app.engineering import friction, units
from app.engineering.constants import (
    GRAVITY_M_S2,
    PIPE_ROUGHNESS_MM,
    WATER_DENSITY_KG_M3,
    WATTS_PER_KILOWATT,
)
from app.engineering.models import (
    Flow,
    Head,
    HeadComponent,
    HydraulicInput,
    HydraulicResult,
    Levels,
    Pipe,
    Power,
)

METHODOLOGY_VERSION = "1.0.0"

HIGH_VELOCITY_M_S = 2.5
LOW_VELOCITY_M_S = 0.5
HIGH_FRICTION_SHARE = 0.30

DISCLAIMER = (
    "Simplified estimate for preliminary sizing. It is not a certified engineering design. "
    "Confirm with a site survey, a pumping test and the manufacturer's published pump curves "
    "before selecting or installing equipment."
)


def hydraulic_power_kw(flow_m3_s: float, head_m: float) -> float:
    """Power delivered to the water: P = rho * g * Q * H."""
    return WATER_DENSITY_KG_M3 * GRAVITY_M_S2 * flow_m3_s * head_m / WATTS_PER_KILOWATT


def calculate(data: HydraulicInput) -> HydraulicResult:
    flow_m3_s = units.flow_to_m3_per_s(data.flow_rate, data.flow_rate_unit)
    diameter_m = units.mm_to_m(data.pipe_internal_diameter_mm)
    roughness_mm = PIPE_ROUGHNESS_MM[data.pipe_material]

    setting_defaulted = data.pump_setting_depth_m is None
    pump_setting_m = (
        data.pumping_water_level_m if setting_defaulted else data.pump_setting_depth_m
    )

    # Head is measured from the pumping water level, never from the borewell depth.
    static_head_m = data.static_water_level_m + data.delivery_height_m
    total_static_lift_m = data.pumping_water_level_m + data.delivery_height_m

    riser_length_m = pump_setting_m
    total_length_m = riser_length_m + data.delivery_height_m + data.horizontal_pipe_length_m

    velocity = friction.flow_velocity_m_s(flow_m3_s, diameter_m)
    reynolds = friction.reynolds_number(velocity, diameter_m)
    regime = friction.flow_regime(reynolds)
    factor = friction.darcy_friction_factor(reynolds, units.mm_to_m(roughness_mm) / diameter_m)
    pipe_loss_m = friction.friction_head_loss_m(factor, total_length_m, diameter_m, velocity)
    minor_loss_m = pipe_loss_m * data.minor_loss_fraction

    breakdown = [
        HeadComponent(
            key="pumping_lift",
            label="Lift from pumping water level",
            value_m=data.pumping_water_level_m,
        ),
        HeadComponent(
            key="delivery_elevation", label="Delivery elevation", value_m=data.delivery_height_m
        ),
        HeadComponent(key="pipe_friction", label="Pipe friction", value_m=pipe_loss_m),
        HeadComponent(key="minor_losses", label="Fittings allowance", value_m=minor_loss_m),
        HeadComponent(
            key="residual_pressure",
            label="Residual pressure head",
            value_m=data.residual_pressure_head_m,
        ),
    ]
    tdh_m = sum(component.value_m for component in breakdown)

    p_hydraulic = hydraulic_power_kw(flow_m3_s, tdh_m)
    p_shaft = p_hydraulic / data.pump_efficiency
    p_input = p_shaft / data.motor_efficiency

    assumptions = [
        "Clean water at 20 degrees C (density 998.2 kg/m3, kinematic viscosity 1.004e-6 m2/s).",
        "Pipe friction by Darcy-Weisbach with the Swamee-Jain friction factor.",
        (
            f"Roughness {roughness_mm} mm is a typical value for new "
            f"{data.pipe_material.value} pipe; aged pipe is rougher."
        ),
        "One internal diameter is used for the riser and the delivery pipe.",
        f"Fittings and valves are allowed for as {data.minor_loss_fraction:.0%} of pipe friction.",
        "Velocity head at the outlet is neglected.",
        (
            f"Pump efficiency {data.pump_efficiency:.0%} and motor efficiency "
            f"{data.motor_efficiency:.0%} are assumptions, not manufacturer data."
        ),
        "The pumping water level is taken as stable at the required flow rate.",
    ]

    warnings: list[str] = []
    if setting_defaulted:
        warnings.append(
            "Pump setting depth was not supplied; riser length is taken as the pumping water "
            "level. A real pump is set deeper, which adds a little friction."
        )
    if velocity > HIGH_VELOCITY_M_S:
        warnings.append(
            f"Pipe velocity {velocity:.2f} m/s is high; friction loss and water-hammer risk "
            "rise quickly. Consider a larger pipe."
        )
    elif velocity < LOW_VELOCITY_M_S:
        warnings.append(
            f"Pipe velocity {velocity:.2f} m/s is low; sediment may settle in the pipe."
        )
    if regime == "transitional":
        warnings.append(
            "Flow is in the transitional regime; the friction factor there is an interpolated "
            "estimate."
        )
    if tdh_m > 0 and (pipe_loss_m + minor_loss_m) / tdh_m > HIGH_FRICTION_SHARE:
        warnings.append(
            "Friction is more than 30% of total dynamic head; a larger pipe would cut "
            "running cost."
        )

    return HydraulicResult(
        methodology_version=METHODOLOGY_VERSION,
        levels=Levels(
            borewell_depth_m=data.borewell_depth_m,
            static_water_level_m=data.static_water_level_m,
            pumping_water_level_m=data.pumping_water_level_m,
            pump_setting_depth_m=pump_setting_m,
            drawdown_m=data.pumping_water_level_m - data.static_water_level_m,
            delivery_elevation_m=data.delivery_height_m,
        ),
        head=Head(
            static_head_m=static_head_m,
            total_static_lift_m=total_static_lift_m,
            pipe_friction_loss_m=pipe_loss_m,
            minor_loss_m=minor_loss_m,
            total_friction_loss_m=pipe_loss_m + minor_loss_m,
            residual_pressure_head_m=data.residual_pressure_head_m,
            total_dynamic_head_m=tdh_m,
        ),
        tdh_breakdown=breakdown,
        pipe=Pipe(
            material=data.pipe_material,
            roughness_mm=roughness_mm,
            internal_diameter_m=diameter_m,
            riser_length_m=riser_length_m,
            total_length_m=total_length_m,
            velocity_m_s=velocity,
            reynolds_number=reynolds,
            flow_regime=regime,
            friction_factor=factor,
        ),
        flow=Flow(
            m3_per_s=flow_m3_s,
            m3_per_h=units.m3_per_s_to_m3_per_h(flow_m3_s),
            l_per_s=units.m3_per_s_to_l_per_s(flow_m3_s),
            l_per_min=units.m3_per_s_to_l_per_min(flow_m3_s),
        ),
        power=Power(
            hydraulic_power_kw=p_hydraulic,
            shaft_power_kw=p_shaft,
            input_power_kw=p_input,
            input_power_hp=units.kw_to_hp(p_input),
            pump_efficiency=data.pump_efficiency,
            motor_efficiency=data.motor_efficiency,
            overall_efficiency=data.pump_efficiency * data.motor_efficiency,
        ),
        assumptions=assumptions,
        warnings=warnings,
        disclaimer=DISCLAIMER,
    )

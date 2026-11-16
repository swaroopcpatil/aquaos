"""Typed input and output models for the hydraulic engine."""

from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.engineering.constants import MAX_FLOW_M3_S, PipeMaterial
from app.engineering.units import FlowUnit, flow_to_m3_per_s


class HydraulicInput(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    borewell_depth_m: float = Field(gt=0, le=2000)
    static_water_level_m: float = Field(ge=0, description="Depth below ground, pump off.")
    pumping_water_level_m: float = Field(ge=0, description="Depth below ground while pumping.")
    pump_setting_depth_m: float | None = Field(default=None, gt=0)
    delivery_height_m: float = Field(ge=0, le=1000)
    horizontal_pipe_length_m: float = Field(ge=0, le=50000)
    pipe_internal_diameter_mm: float = Field(ge=10, le=1000)
    flow_rate: float = Field(gt=0)
    flow_rate_unit: FlowUnit = FlowUnit.M3_PER_H
    pipe_material: PipeMaterial = PipeMaterial.PVC
    minor_loss_fraction: float = Field(default=0.10, ge=0, le=1)
    residual_pressure_head_m: float = Field(default=0.0, ge=0, le=200)
    pump_efficiency: float = Field(default=0.60, gt=0, le=1)
    motor_efficiency: float = Field(default=0.80, gt=0, le=1)

    @model_validator(mode="after")
    def _check_consistency(self) -> Self:
        if self.pumping_water_level_m < self.static_water_level_m:
            raise ValueError(
                "Pumping water level cannot be shallower than the static water level: "
                "the water level drops while pumping."
            )
        if self.pumping_water_level_m >= self.borewell_depth_m:
            raise ValueError("Pumping water level must be above the bottom of the borewell.")
        if self.pump_setting_depth_m is not None:
            if self.pump_setting_depth_m < self.pumping_water_level_m:
                raise ValueError(
                    "Pump setting depth must be at or below the pumping water level, "
                    "otherwise the pump runs dry."
                )
            if self.pump_setting_depth_m > self.borewell_depth_m:
                raise ValueError("Pump setting depth cannot exceed the borewell depth.")
        if flow_to_m3_per_s(self.flow_rate, self.flow_rate_unit) > MAX_FLOW_M3_S:
            raise ValueError(
                f"Flow rate exceeds the supported maximum of {MAX_FLOW_M3_S} m3/s."
            )
        return self


class Levels(BaseModel):
    borewell_depth_m: float
    static_water_level_m: float
    pumping_water_level_m: float
    pump_setting_depth_m: float
    drawdown_m: float
    delivery_elevation_m: float


class Head(BaseModel):
    static_head_m: float
    total_static_lift_m: float
    pipe_friction_loss_m: float
    minor_loss_m: float
    total_friction_loss_m: float
    residual_pressure_head_m: float
    total_dynamic_head_m: float


class HeadComponent(BaseModel):
    key: str
    label: str
    value_m: float


class Pipe(BaseModel):
    material: PipeMaterial
    roughness_mm: float
    internal_diameter_m: float
    riser_length_m: float
    total_length_m: float
    velocity_m_s: float
    reynolds_number: float
    flow_regime: str
    friction_factor: float


class Flow(BaseModel):
    m3_per_s: float
    m3_per_h: float
    l_per_s: float
    l_per_min: float


class Power(BaseModel):
    hydraulic_power_kw: float
    shaft_power_kw: float
    input_power_kw: float
    input_power_hp: float
    pump_efficiency: float
    motor_efficiency: float
    overall_efficiency: float


class HydraulicResult(BaseModel):
    methodology_version: str
    levels: Levels
    head: Head
    tdh_breakdown: list[HeadComponent]
    pipe: Pipe
    flow: Flow
    power: Power
    assumptions: list[str]
    warnings: list[str]
    disclaimer: str

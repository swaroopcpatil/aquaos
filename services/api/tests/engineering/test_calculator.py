import math

import pytest
from pydantic import ValidationError

from app.engineering import HydraulicInput, calculate
from app.engineering.calculator import hydraulic_power_kw

BASE = {
    "borewell_depth_m": 120.0,
    "static_water_level_m": 40.0,
    "pumping_water_level_m": 60.0,
    "delivery_height_m": 5.0,
    "horizontal_pipe_length_m": 100.0,
    "pipe_internal_diameter_mm": 50.0,
    "flow_rate": 10.0,
}


def make(**overrides) -> HydraulicInput:
    return HydraulicInput(**{**BASE, **overrides})


def test_normal_case_matches_hand_calculation():
    """Independent hand calculation of the base case.

    Q = 10/3600 m3/s, D = 0.05 m, v = 1.41471 m/s, Re = v*D/1.004e-6 = 70454
    eps/D = 0.0015/50 = 3e-5, Swamee-Jain f = 0.25/log10(3e-5/3.7 + 5.74/Re^0.9)^2 = 0.019395
    L = 60 + 5 + 100 = 165 m, h_f = f*(L/D)*v^2/(2g) = 6.5311 m, minor = 0.6531 m
    TDH = 60 + 5 + 6.5311 + 0.6531 = 72.1842 m
    P_h = 998.2*9.80665*Q*TDH/1000 = 1.96281 kW
    """
    r = calculate(make())
    assert r.pipe.velocity_m_s == pytest.approx(1.41471, rel=1e-5)
    assert r.pipe.reynolds_number == pytest.approx(70454, rel=1e-4)
    assert r.pipe.flow_regime == "turbulent"
    assert r.pipe.friction_factor == pytest.approx(0.019395, rel=1e-3)
    assert r.pipe.total_length_m == pytest.approx(165.0)
    assert r.head.pipe_friction_loss_m == pytest.approx(6.5311, rel=1e-3)
    assert r.head.minor_loss_m == pytest.approx(0.65311, rel=1e-3)
    assert r.head.total_dynamic_head_m == pytest.approx(72.1842, rel=1e-4)
    assert r.power.hydraulic_power_kw == pytest.approx(1.96281, rel=1e-4)
    assert r.power.shaft_power_kw == pytest.approx(1.96281 / 0.6, rel=1e-4)
    assert r.power.input_power_kw == pytest.approx(1.96281 / 0.48, rel=1e-4)
    assert r.power.input_power_hp == pytest.approx(1.96281 / 0.48 / 0.7457, rel=1e-4)
    assert r.power.overall_efficiency == pytest.approx(0.48)


def test_levels_and_static_heads():
    r = calculate(make())
    assert r.levels.drawdown_m == pytest.approx(20.0)
    assert r.head.static_head_m == pytest.approx(45.0)
    assert r.head.total_static_lift_m == pytest.approx(65.0)
    assert r.levels.pump_setting_depth_m == pytest.approx(60.0)


def test_breakdown_sums_exactly_to_tdh():
    r = calculate(make(residual_pressure_head_m=12.5))
    assert sum(c.value_m for c in r.tdh_breakdown) == r.head.total_dynamic_head_m
    assert [c.key for c in r.tdh_breakdown] == [
        "pumping_lift", "delivery_elevation", "pipe_friction", "minor_losses", "residual_pressure",
    ]


def test_borewell_depth_does_not_affect_head():
    shallow = calculate(make(borewell_depth_m=80.0))
    deep = calculate(make(borewell_depth_m=500.0))
    assert shallow.head.total_dynamic_head_m == deep.head.total_dynamic_head_m
    assert shallow.power == deep.power


def test_reproducible_for_identical_inputs():
    first = calculate(make()).model_dump_json()
    for _ in range(5):
        assert calculate(make()).model_dump_json() == first


def test_flow_unit_does_not_change_result():
    a = calculate(make(flow_rate=18.0, flow_rate_unit="m3_per_h"))
    b = calculate(make(flow_rate=300.0, flow_rate_unit="l_per_min"))
    c = calculate(make(flow_rate=5.0, flow_rate_unit="l_per_s"))
    for other in (b, c):
        assert other.head.total_dynamic_head_m == pytest.approx(a.head.total_dynamic_head_m)
        assert other.power.input_power_kw == pytest.approx(a.power.input_power_kw)
    assert a.flow.l_per_min == pytest.approx(300.0)
    assert a.flow.l_per_s == pytest.approx(5.0)


def test_pump_setting_depth_lengthens_riser():
    default = calculate(make())
    deeper = calculate(make(pump_setting_depth_m=90.0))
    assert deeper.pipe.riser_length_m == pytest.approx(90.0)
    assert deeper.pipe.total_length_m == pytest.approx(195.0)
    assert deeper.head.pipe_friction_loss_m > default.head.pipe_friction_loss_m
    assert deeper.head.total_static_lift_m == default.head.total_static_lift_m
    assert any("setting depth" in w for w in default.warnings)
    assert not any("setting depth" in w for w in deeper.warnings)


def test_rougher_pipe_and_smaller_pipe_lose_more_head():
    pvc = calculate(make())
    iron = calculate(make(pipe_material="cast_iron"))
    narrow = calculate(make(pipe_internal_diameter_mm=40.0))
    assert iron.head.pipe_friction_loss_m > pvc.head.pipe_friction_loss_m
    assert narrow.head.pipe_friction_loss_m > pvc.head.pipe_friction_loss_m


def test_efficiency_changes_input_power_only():
    low = calculate(make(pump_efficiency=0.4))
    high = calculate(make(pump_efficiency=0.8))
    assert low.power.hydraulic_power_kw == high.power.hydraulic_power_kw
    assert low.power.input_power_kw == pytest.approx(2 * high.power.input_power_kw)


def test_hydraulic_power_formula():
    assert hydraulic_power_kw(0.01, 50.0) == pytest.approx(998.2 * 9.80665 * 0.01 * 50 / 1000)


def test_warnings_for_high_velocity_and_friction_share():
    r = calculate(make(pipe_internal_diameter_mm=25.0))
    assert r.pipe.velocity_m_s > 2.5
    assert any("velocity" in w and "high" in w for w in r.warnings)
    assert any("30%" in w for w in r.warnings)


def test_low_velocity_and_laminar_and_transitional_regimes():
    slow = calculate(make(flow_rate=0.5, pipe_internal_diameter_mm=200.0))
    assert any("low" in w for w in slow.warnings)
    laminar = calculate(make(flow_rate=0.001, flow_rate_unit="l_per_s", pipe_internal_diameter_mm=20))
    assert laminar.pipe.flow_regime == "laminar"
    assert laminar.pipe.friction_factor == pytest.approx(64 / laminar.pipe.reynolds_number)
    trans = calculate(make(flow_rate=0.05, flow_rate_unit="l_per_s", pipe_internal_diameter_mm=20))
    assert trans.pipe.flow_regime == "transitional"
    assert any("transitional" in w for w in trans.warnings)


def test_extreme_but_valid_inputs_stay_finite():
    big = calculate(make(
        borewell_depth_m=2000, static_water_level_m=1500, pumping_water_level_m=1999,
        delivery_height_m=1000, horizontal_pipe_length_m=50000,
        pipe_internal_diameter_mm=10, flow_rate=1.0, flow_rate_unit="m3_per_s",
        pump_efficiency=0.01, motor_efficiency=0.01, minor_loss_fraction=1.0,
    ))
    tiny = calculate(make(
        borewell_depth_m=1.0, static_water_level_m=0.0, pumping_water_level_m=0.0,
        delivery_height_m=0.0, horizontal_pipe_length_m=0.0,
        pipe_internal_diameter_mm=1000, flow_rate=1e-9,
    ))
    for r in (big, tiny):
        values = [r.head.total_dynamic_head_m, r.power.input_power_kw, r.pipe.friction_factor]
        assert all(math.isfinite(v) and v >= 0 for v in values)
    assert tiny.head.total_dynamic_head_m == 0.0


@pytest.mark.parametrize(
    "overrides",
    [
        {"flow_rate": 0},
        {"flow_rate": -5},
        {"flow_rate": float("nan")},
        {"flow_rate": float("inf")},
        {"flow_rate": 5000, "flow_rate_unit": "m3_per_h"},
        {"flow_rate_unit": "gpm"},
        {"pipe_internal_diameter_mm": 0},
        {"pipe_internal_diameter_mm": -50},
        {"pipe_internal_diameter_mm": 5},
        {"pipe_internal_diameter_mm": 5000},
        {"borewell_depth_m": 0},
        {"static_water_level_m": -1},
        {"pumping_water_level_m": 30},          # shallower than static level
        {"pumping_water_level_m": 120},         # at the bottom of the borewell
        {"pumping_water_level_m": 150},         # below the borewell
        {"pump_setting_depth_m": 50},           # above pumping level
        {"pump_setting_depth_m": 130},          # below the borewell
        {"delivery_height_m": -1},
        {"horizontal_pipe_length_m": -1},
        {"pipe_material": "bamboo"},
        {"pump_efficiency": 0},
        {"pump_efficiency": 1.2},
        {"motor_efficiency": 0},
        {"minor_loss_fraction": -0.1},
        {"residual_pressure_head_m": -1},
        {"unknown_field": 1},
    ],
)
def test_invalid_inputs_are_rejected(overrides):
    with pytest.raises(ValidationError):
        make(**overrides)


def test_missing_pumping_water_level_is_rejected():
    data = {k: v for k, v in BASE.items() if k != "pumping_water_level_m"}
    with pytest.raises(ValidationError) as exc:
        HydraulicInput(**data)
    assert "pumping_water_level_m" in str(exc.value)

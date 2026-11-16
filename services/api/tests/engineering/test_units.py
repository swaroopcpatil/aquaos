import pytest

from app.engineering import units
from app.engineering.units import FlowUnit


@pytest.mark.parametrize(
    ("value", "unit", "expected"),
    [
        (3600.0, FlowUnit.M3_PER_H, 1.0),
        (10.0, FlowUnit.M3_PER_H, 10.0 / 3600.0),
        (60000.0, FlowUnit.L_PER_MIN, 1.0),
        (1000.0, FlowUnit.L_PER_S, 1.0),
        (0.25, FlowUnit.M3_PER_S, 0.25),
    ],
)
def test_flow_to_si(value, unit, expected):
    assert units.flow_to_m3_per_s(value, unit) == pytest.approx(expected, rel=1e-12)


@pytest.mark.parametrize("unit", list(FlowUnit))
def test_flow_round_trip(unit):
    si = units.flow_to_m3_per_s(123.456, unit)
    back = {
        FlowUnit.M3_PER_H: units.m3_per_s_to_m3_per_h,
        FlowUnit.L_PER_MIN: units.m3_per_s_to_l_per_min,
        FlowUnit.L_PER_S: units.m3_per_s_to_l_per_s,
        FlowUnit.M3_PER_S: lambda v: v,
    }[unit](si)
    assert back == pytest.approx(123.456, rel=1e-12)


def test_same_flow_in_different_units_is_equal():
    a = units.flow_to_m3_per_s(18.0, FlowUnit.M3_PER_H)
    b = units.flow_to_m3_per_s(300.0, FlowUnit.L_PER_MIN)
    c = units.flow_to_m3_per_s(5.0, FlowUnit.L_PER_S)
    assert a == pytest.approx(b, rel=1e-12) == pytest.approx(c, rel=1e-12)


def test_length_and_power():
    assert units.mm_to_m(50.0) == pytest.approx(0.05)
    assert units.kw_to_hp(0.7457) == pytest.approx(1.0)
    assert units.kw_to_hp(3.7285) == pytest.approx(5.0)

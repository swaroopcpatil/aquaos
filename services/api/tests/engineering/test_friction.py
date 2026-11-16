import math

import pytest

from app.engineering import friction


def test_velocity_matches_continuity():
    # 10 m3/h through 50 mm: v = Q / A
    q = 10.0 / 3600.0
    assert friction.flow_velocity_m_s(q, 0.05) == pytest.approx(q / (math.pi * 0.05**2 / 4))
    assert friction.flow_velocity_m_s(q, 0.05) == pytest.approx(1.41471, rel=1e-5)


def test_velocity_rejects_zero_diameter():
    with pytest.raises(ValueError):
        friction.flow_velocity_m_s(0.001, 0.0)


def test_reynolds_number():
    assert friction.reynolds_number(1.0, 0.1, 1.0e-6) == pytest.approx(100000.0)


@pytest.mark.parametrize(
    ("reynolds", "regime"),
    [(500, "laminar"), (1999.9, "laminar"), (2000, "transitional"), (3999, "transitional"),
     (4000, "turbulent"), (1e6, "turbulent")],
)
def test_flow_regime(reynolds, regime):
    assert friction.flow_regime(reynolds) == regime


def test_laminar_factor():
    assert friction.darcy_friction_factor(1000.0, 0.001) == pytest.approx(0.064)


@pytest.mark.parametrize(
    ("reynolds", "rel_roughness"),
    [(1e4, 0.0), (1e5, 1e-4), (1e5, 1e-3), (1e6, 1e-5), (1e6, 1e-2), (5e4, 3e-5)],
)
def test_swamee_jain_agrees_with_colebrook(reynolds, rel_roughness):
    """Swamee-Jain is an explicit fit to Colebrook-White; check it against the implicit form."""
    f = 0.02
    for _ in range(100):
        f = (-2.0 * math.log10(rel_roughness / 3.7 + 2.51 / (reynolds * math.sqrt(f)))) ** -2
    assert friction.darcy_friction_factor(reynolds, rel_roughness) == pytest.approx(f, rel=0.03)


def test_factor_is_continuous_across_regime_limits():
    eps = 1e-4
    for limit in (2000.0, 4000.0):
        below = friction.darcy_friction_factor(limit - 1e-6, eps)
        above = friction.darcy_friction_factor(limit + 1e-6, eps)
        assert below == pytest.approx(above, rel=1e-6)


def test_factor_rejects_bad_input():
    with pytest.raises(ValueError):
        friction.darcy_friction_factor(0.0, 0.001)
    with pytest.raises(ValueError):
        friction.darcy_friction_factor(1e5, -0.1)


def test_darcy_weisbach_head_loss():
    # f=0.02, L=100 m, D=0.1 m, v=2 m/s -> 0.02 * 1000 * 4 / (2 * 9.80665)
    assert friction.friction_head_loss_m(0.02, 100.0, 0.1, 2.0) == pytest.approx(4.07886, rel=1e-5)


def test_head_loss_scales_with_length_and_falls_with_diameter():
    base = friction.friction_head_loss_m(0.02, 100.0, 0.1, 2.0)
    assert friction.friction_head_loss_m(0.02, 200.0, 0.1, 2.0) == pytest.approx(2 * base)
    assert friction.friction_head_loss_m(0.02, 100.0, 0.2, 2.0) == pytest.approx(base / 2)

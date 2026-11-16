# Hydraulic methodology (version 1.0.0)

Code: `services/api/app/engineering/`. Every function is pure and deterministic. No AI model takes part in any calculation, and the AI Advisor can read results but cannot change them.

**This is a simplified estimate for preliminary sizing. It is not a certified engineering design.** Confirm with a site survey, a pumping test and the manufacturer's published pump curves.

## Definitions

All depths are measured downward from ground level; delivery height is measured upward from ground level.

| Quantity | Formula |
| --- | --- |
| Drawdown | pumping water level − static water level |
| Static head | static water level + delivery height (lift with the pump off) |
| Total static lift | pumping water level + delivery height |
| Total dynamic head (TDH) | total static lift + pipe friction + fittings allowance + residual pressure head |

Borewell depth is **not** a head term. It is used only to check that the water levels and pump setting are physically possible.

## Pipe friction

Darcy–Weisbach: `h_f = f · (L / D) · v² / (2g)`

- `v = Q / (π D² / 4)`, `Re = v · D / ν`
- `L` = riser length + delivery height + horizontal length. Riser length is the pump setting depth; if that is not supplied it is taken as the pumping water level and a warning is returned.
- Friction factor `f`:
  - `Re < 2000` (laminar): `64 / Re`
  - `Re ≥ 4000` (turbulent): Swamee–Jain, `f = 0.25 / [log10(ε / (3.7 D) + 5.74 / Re^0.9)]²`
  - between: linear interpolation between the two limits, so the function is continuous. Real transitional flow is unstable; a warning is returned.
- Fittings and valves: `minor_loss_fraction × h_f` (default 10%).

Swamee–Jain is an explicit approximation of Colebrook–White. The test suite checks it against an iterated Colebrook solution to within 3%.

### Roughness (new pipe, typical textbook values)

| Material | ε (mm) |
| --- | --- |
| PVC | 0.0015 |
| HDPE | 0.007 |
| Steel | 0.045 |
| Galvanised iron | 0.15 |
| Cast iron | 0.26 |

## Power

- Hydraulic power: `P_h = ρ · g · Q · TDH`
- Shaft power: `P_h / pump efficiency`
- Electrical input power: `shaft power / motor efficiency`
- 1 HP = 0.7457 kW

Efficiencies are user-supplied assumptions (defaults 60% pump, 80% motor), not manufacturer data. The result is an estimate of demand at the duty point, not a pump selection.

## Constants

`g` = 9.80665 m/s², water at 20 °C: `ρ` = 998.2 kg/m³, `ν` = 1.004 × 10⁻⁶ m²/s.

## Units

The engine works in SI. Conversions live only in `units.py`: flow (m³/h, L/min, L/s, m³/s → m³/s), mm → m, kW → HP.

## Validation

Rejected with HTTP 422: missing required fields (including pumping water level), non-numeric, NaN or infinite values, zero or negative flow, diameter outside 10–1000 mm, pumping level shallower than static level, pumping level at or below the borewell bottom, pump setting above the pumping level or below the borewell bottom, efficiencies outside (0, 1], flow above 1 m³/s, unknown fields. Full limits are in `docs/api/CONTRACT.md`.

## Limitations

- One pipe diameter and material for riser and delivery line.
- Fittings are a percentage allowance, not itemised K-values.
- Outlet velocity head is neglected.
- Water properties are fixed at 20 °C; no allowance for sand, gas or temperature.
- The pumping water level is an input. The engine does not model the aquifer, so it cannot tell whether the borewell can sustain the requested flow.
- Roughness values are for new pipe; scaled or aged pipe loses more head.
- No motor cable loss, voltage drop, NPSH or submergence check.
- No pump curve matching. Recommending a specific pump requires verified manufacturer curve data, which the system does not yet hold.

# AquaOS API contract (v1)

Base URL (local): `http://localhost:8000`. All bodies are JSON. Validation failures return HTTP 422 in FastAPI's standard shape (`{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}`).

## GET /api/v1/health

`200 {"status": "ok", "service": "aquaos-api", "version": "<semver>"}`

## POST /api/v1/hydraulics/calculate

Deterministic engineering calculation. No AI is involved.

### Request

| Field | Type | Required | Default | Rule |
| --- | --- | --- | --- | --- |
| `borewell_depth_m` | number | yes | | > 0, ≤ 2000 |
| `static_water_level_m` | number | yes | | depth below ground, ≥ 0 |
| `pumping_water_level_m` | number | yes | | depth below ground, ≥ static level, < borewell depth |
| `pump_setting_depth_m` | number | no | = pumping water level | ≥ pumping level, ≤ borewell depth |
| `delivery_height_m` | number | yes | | discharge elevation above ground, ≥ 0, ≤ 1000 |
| `horizontal_pipe_length_m` | number | yes | | ≥ 0, ≤ 50000 |
| `pipe_internal_diameter_mm` | number | yes | | ≥ 10, ≤ 1000 |
| `flow_rate` | number | yes | | > 0 |
| `flow_rate_unit` | string | no | `m3_per_h` | `m3_per_h`, `l_per_min`, `l_per_s`, `m3_per_s` |
| `pipe_material` | string | no | `pvc` | `pvc`, `hdpe`, `gi`, `steel`, `cast_iron` |
| `minor_loss_fraction` | number | no | 0.10 | 0 to 1; fittings allowance as a fraction of pipe friction |
| `residual_pressure_head_m` | number | no | 0 | ≥ 0, ≤ 200; pressure head required at the outlet |
| `pump_efficiency` | number | no | 0.60 | > 0, ≤ 1 |
| `motor_efficiency` | number | no | 0.80 | > 0, ≤ 1 |

### Response 200

```json
{
  "methodology_version": "1.0.0",
  "levels": {
    "borewell_depth_m": 120.0,
    "static_water_level_m": 40.0,
    "pumping_water_level_m": 60.0,
    "pump_setting_depth_m": 60.0,
    "drawdown_m": 20.0,
    "delivery_elevation_m": 5.0
  },
  "head": {
    "static_head_m": 45.0,
    "total_static_lift_m": 65.0,
    "pipe_friction_loss_m": 3.1,
    "minor_loss_m": 0.31,
    "total_friction_loss_m": 3.41,
    "residual_pressure_head_m": 0.0,
    "total_dynamic_head_m": 68.41
  },
  "tdh_breakdown": [
    {"key": "pumping_lift", "label": "Lift from pumping water level", "value_m": 60.0},
    {"key": "delivery_elevation", "label": "Delivery elevation", "value_m": 5.0},
    {"key": "pipe_friction", "label": "Pipe friction", "value_m": 3.1},
    {"key": "minor_losses", "label": "Fittings allowance", "value_m": 0.31},
    {"key": "residual_pressure", "label": "Residual pressure head", "value_m": 0.0}
  ],
  "pipe": {
    "material": "pvc",
    "roughness_mm": 0.0015,
    "internal_diameter_m": 0.05,
    "riser_length_m": 60.0,
    "total_length_m": 165.0,
    "velocity_m_s": 1.41,
    "reynolds_number": 70400.0,
    "flow_regime": "turbulent",
    "friction_factor": 0.0194
  },
  "flow": {"m3_per_s": 0.002778, "m3_per_h": 10.0, "l_per_s": 2.778, "l_per_min": 166.67},
  "power": {
    "hydraulic_power_kw": 1.86,
    "shaft_power_kw": 3.1,
    "input_power_kw": 3.88,
    "input_power_hp": 5.2,
    "pump_efficiency": 0.6,
    "motor_efficiency": 0.8,
    "overall_efficiency": 0.48
  },
  "assumptions": ["..."],
  "warnings": ["..."],
  "disclaimer": "..."
}
```

Numbers above illustrate the shape only. `flow_regime` is `laminar`, `transitional` or `turbulent`. The sum of `tdh_breakdown[].value_m` equals `head.total_dynamic_head_m`.

## POST /api/v1/advisor/explain

Explains a calculation result in plain language. The advisor never changes numbers; it only reads them.

### Request

```json
{
  "calculation": { "...": "the full 200 response of /hydraulics/calculate" },
  "audience": "farmer",
  "question": "optional free text, max 500 chars"
}
```

`audience` is `farmer`, `dealer` or `technician` (default `farmer`).

### Response 200

```json
{
  "provider": "mock",
  "summary": "string",
  "key_points": ["string"],
  "assumptions": ["string"],
  "follow_up_questions": ["string"],
  "disclaimer": "string"
}
```

`503 {"detail": "..."}` when the AI provider fails or returns output that does not validate. The calculation workflow must keep working when this endpoint fails.

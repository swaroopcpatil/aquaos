"""Physical constants and reference data. All values are SI unless the name says otherwise."""

from enum import StrEnum

GRAVITY_M_S2 = 9.80665
# Clean water at 20 degrees C.
WATER_DENSITY_KG_M3 = 998.2
WATER_KINEMATIC_VISCOSITY_M2_S = 1.004e-6

WATTS_PER_KILOWATT = 1000.0
KILOWATTS_PER_HP = 0.7457  # mechanical horsepower

LAMINAR_REYNOLDS_LIMIT = 2000.0
TURBULENT_REYNOLDS_LIMIT = 4000.0

MAX_FLOW_M3_S = 1.0


class PipeMaterial(StrEnum):
    PVC = "pvc"
    HDPE = "hdpe"
    GI = "gi"
    STEEL = "steel"
    CAST_IRON = "cast_iron"


# Typical absolute roughness of new pipe, in millimetres (standard textbook values).
# Aged or scaled pipe is rougher; see the methodology document.
PIPE_ROUGHNESS_MM: dict[PipeMaterial, float] = {
    PipeMaterial.PVC: 0.0015,
    PipeMaterial.HDPE: 0.007,
    PipeMaterial.STEEL: 0.045,
    PipeMaterial.GI: 0.15,
    PipeMaterial.CAST_IRON: 0.26,
}

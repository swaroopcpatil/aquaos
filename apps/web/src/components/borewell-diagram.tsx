import type { CalculationResponse } from "@/lib/api";

type Marker = { key: string; label: string; depth: number; color: string };

export function BorewellDiagram({ levels }: { levels: CalculationResponse["levels"] }) {
  const H = 440;
  const top = 24;
  const bottom = 16;
  const above = Math.max(levels.delivery_elevation_m, 0);
  const total = above + levels.borewell_depth_m;
  const scale = (H - top - bottom) / total;
  const groundY = top + above * scale;
  const y = (depthBelowGround: number) => groundY + depthBelowGround * scale;

  const wellX = 120;
  const wellW = 36;

  const markers: Marker[] = [
    { key: "delivery", label: `Delivery elevation +${levels.delivery_elevation_m} m`, depth: -above, color: "#a78bfa" },
    { key: "ground", label: "Ground level 0 m", depth: 0, color: "#94a3b8" },
    { key: "static", label: `Static water level ${levels.static_water_level_m} m`, depth: levels.static_water_level_m, color: "#38bdf8" },
    { key: "pumping", label: `Pumping water level ${levels.pumping_water_level_m} m`, depth: levels.pumping_water_level_m, color: "#22d3ee" },
    { key: "pump", label: `Pump setting ${levels.pump_setting_depth_m} m`, depth: levels.pump_setting_depth_m, color: "#fbbf24" },
    { key: "bottom", label: `Borewell depth ${levels.borewell_depth_m} m`, depth: levels.borewell_depth_m, color: "#94a3b8" },
  ];

  // Spread label positions so text does not overlap (min 15px gap), keeping order by depth.
  const sorted = [...markers].sort((a, b) => a.depth - b.depth);
  const labelY: Record<string, number> = {};
  let prev = -Infinity;
  for (const m of sorted) {
    const ly = Math.max(y(m.depth), prev + 15);
    labelY[m.key] = ly;
    prev = ly;
  }

  const staticY = y(levels.static_water_level_m);
  const bottomY = y(levels.borewell_depth_m);
  const pumpY = y(levels.pump_setting_depth_m);

  return (
    <svg
      viewBox={`0 0 420 ${H + 20}`}
      className="h-auto w-full max-w-md"
      role="img"
      aria-label={`Borewell cross-section to scale: depth ${levels.borewell_depth_m} m, static water level ${levels.static_water_level_m} m, pumping water level ${levels.pumping_water_level_m} m, pump at ${levels.pump_setting_depth_m} m, delivery elevation ${levels.delivery_elevation_m} m.`}
    >
      {/* ground */}
      <rect x="0" y={groundY} width="420" height={bottomY - groundY + bottom} fill="#1a2a47" opacity="0.5" />
      {/* static water body */}
      <rect x={wellX} y={staticY} width={wellW} height={bottomY - staticY} fill="#0ea5e9" opacity="0.45" />
      {/* borewell casing */}
      <rect x={wellX} y={groundY} width={wellW} height={bottomY - groundY} fill="none" stroke="#cbd5e1" strokeWidth="2" />
      {/* delivery riser above ground */}
      {above > 0 && (
        <line x1={wellX + wellW / 2} y1={y(-above)} x2={wellX + wellW / 2} y2={groundY} stroke="#a78bfa" strokeWidth="3" />
      )}
      {/* pump */}
      <rect x={wellX + 8} y={pumpY - 5} width={wellW - 16} height="10" rx="2" fill="#fbbf24" />
      {markers.map((m) => (
        <g key={m.key}>
          <line
            x1={m.key === "delivery" ? wellX + wellW / 2 : wellX}
            y1={y(m.depth)}
            x2={wellX + wellW + 24}
            y2={y(m.depth)}
            stroke={m.color}
            strokeWidth="1.5"
            strokeDasharray={m.key === "static" || m.key === "pumping" ? "5 3" : undefined}
          />
          <line x1={wellX + wellW + 24} y1={y(m.depth)} x2={wellX + wellW + 32} y2={labelY[m.key]} stroke={m.color} strokeWidth="1" />
          <text x={wellX + wellW + 36} y={labelY[m.key] + 4} fontSize="11" fill={m.color}>
            {m.label}
          </text>
        </g>
      ))}
    </svg>
  );
}

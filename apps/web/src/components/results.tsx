"use client";

import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { CalculationResponse } from "@/lib/api";
import { Card, CardTitle } from "@/components/ui/card";
import { Alert } from "@/components/ui/alert";
import { BorewellDiagram } from "./borewell-diagram";

const fmt = (n: number, d = 2) => n.toLocaleString(undefined, { maximumFractionDigits: d });

function Tile({ label, value, unit, sub }: { label: string; value: string; unit: string; sub?: string }) {
  return (
    <Card className="p-4">
      <div className="text-xs uppercase tracking-wide text-slate-400">{label}</div>
      <div className="mt-1 text-2xl font-bold text-aqua">
        {value} <span className="text-base font-medium text-slate-300">{unit}</span>
      </div>
      {sub && <div className="mt-1 text-xs text-slate-400">{sub}</div>}
    </Card>
  );
}

export function Results({ r }: { r: CalculationResponse }) {
  const pipeRows: [string, string][] = [
    ["Material", r.pipe.material],
    ["Roughness", `${fmt(r.pipe.roughness_mm, 4)} mm`],
    ["Internal diameter", `${fmt(r.pipe.internal_diameter_m * 1000, 1)} mm`],
    ["Riser length", `${fmt(r.pipe.riser_length_m)} m`],
    ["Total length", `${fmt(r.pipe.total_length_m)} m`],
    ["Velocity", `${fmt(r.pipe.velocity_m_s)} m/s`],
    ["Reynolds number", fmt(r.pipe.reynolds_number, 0)],
    ["Flow regime", r.pipe.flow_regime],
    ["Friction factor", fmt(r.pipe.friction_factor, 4)],
    ["Pipe friction loss", `${fmt(r.head.pipe_friction_loss_m)} m`],
    ["Fittings allowance", `${fmt(r.head.minor_loss_m)} m`],
    ["Total friction loss", `${fmt(r.head.total_friction_loss_m)} m`],
  ];

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Tile label="Total dynamic head" value={fmt(r.head.total_dynamic_head_m)} unit="m" />
        <Tile label="Flow" value={fmt(r.flow.m3_per_h)} unit="m³/h" sub={`${fmt(r.flow.l_per_min)} L/min · ${fmt(r.flow.l_per_s)} L/s`} />
        <Tile label="Input power" value={fmt(r.power.input_power_kw)} unit="kW" sub={`Overall efficiency ${fmt(r.power.overall_efficiency * 100, 1)}%`} />
        <Tile label="Input power" value={fmt(r.power.input_power_hp)} unit="HP" sub={`Shaft ${fmt(r.power.shaft_power_kw)} kW`} />
      </div>

      {r.warnings.length > 0 && (
        <Alert variant="warning">
          <p className="mb-1 font-semibold">Warnings</p>
          <ul className="list-disc space-y-1 pl-5">
            {r.warnings.map((w, i) => <li key={i}>{w}</li>)}
          </ul>
        </Alert>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardTitle>TDH breakdown (m)</CardTitle>
          <div className="h-72 w-full" role="img" aria-label={`TDH breakdown: ${r.tdh_breakdown.map((b) => `${b.label} ${b.value_m} m`).join(", ")}`}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={r.tdh_breakdown} layout="vertical" margin={{ left: 8, right: 16 }}>
                <CartesianGrid stroke="#213559" horizontal={false} />
                <XAxis type="number" stroke="#94a3b8" fontSize={12} />
                <YAxis type="category" dataKey="label" width={110} stroke="#94a3b8" fontSize={11} />
                <Tooltip
                  contentStyle={{ background: "#0d1b33", border: "1px solid #213559", color: "#e2e8f0" }}
                  formatter={(v) => [`${fmt(Number(v))} m`, "Head"]}
                />
                <Bar dataKey="value_m" radius={[0, 4, 4, 0]}>
                  {r.tdh_breakdown.map((b) => <Cell key={b.key} fill="#22d3ee" />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
        <Card>
          <CardTitle>Borewell cross-section (to scale)</CardTitle>
          <BorewellDiagram levels={r.levels} />
          <p className="mt-2 text-xs text-slate-400">Drawdown {fmt(r.levels.drawdown_m)} m</p>
        </Card>
      </div>

      <Card>
        <CardTitle>Pipe and friction details</CardTitle>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">Pipe and friction details</caption>
            <tbody>
              {pipeRows.map(([k, v]) => (
                <tr key={k} className="border-b border-line last:border-0">
                  <th scope="row" className="py-2 pr-4 text-left font-normal text-slate-400">{k}</th>
                  <td className="py-2 text-right font-medium">{v}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardTitle>Assumptions</CardTitle>
          <ul className="list-disc space-y-1 pl-5 text-sm text-slate-300">
            {r.assumptions.map((a, i) => <li key={i}>{a}</li>)}
          </ul>
        </Card>
        <Card>
          <CardTitle>Disclaimer</CardTitle>
          <p className="text-sm text-slate-300">{r.disclaimer}</p>
          <p className="mt-2 text-xs text-slate-500">Methodology v{r.methodology_version}</p>
        </Card>
      </div>
    </div>
  );
}

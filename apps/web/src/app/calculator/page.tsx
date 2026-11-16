"use client";

import { useState } from "react";
import { calculate, type CalculationResponse } from "@/lib/api";
import { DEFAULT_VALUES, validate, type FormErrors, type FormValues } from "@/lib/validation";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Alert } from "@/components/ui/alert";
import { Results } from "@/components/results";
import { ExplainPanel } from "@/components/explain-panel";

type NumKey = Exclude<keyof FormValues, "flow_rate_unit" | "pipe_material">;

const REQUIRED: { key: NumKey; label: string; hint?: string }[] = [
  { key: "borewell_depth_m", label: "Borewell depth (m)", hint: "Greater than 0, up to 2000" },
  { key: "static_water_level_m", label: "Static water level (m below ground)", hint: "0 or more" },
  { key: "pumping_water_level_m", label: "Pumping water level (m below ground)", hint: "At or below static level, above borewell depth" },
  { key: "delivery_height_m", label: "Delivery height (m above ground)", hint: "0 to 1000" },
  { key: "horizontal_pipe_length_m", label: "Horizontal pipe length (m)", hint: "0 to 50000" },
  { key: "pipe_internal_diameter_mm", label: "Pipe internal diameter (mm)", hint: "10 to 1000" },
  { key: "flow_rate", label: "Flow rate", hint: "Greater than 0" },
];

const ADVANCED: { key: NumKey; label: string; hint: string }[] = [
  { key: "pump_setting_depth_m", label: "Pump setting depth (m below ground)", hint: "Optional. Between pumping level and borewell depth; blank = pumping level" },
  { key: "minor_loss_fraction", label: "Fittings allowance (fraction of pipe friction)", hint: "0 to 1" },
  { key: "residual_pressure_head_m", label: "Residual pressure head (m)", hint: "0 to 200" },
  { key: "pump_efficiency", label: "Pump efficiency (fraction)", hint: "Greater than 0, up to 1" },
  { key: "motor_efficiency", label: "Motor efficiency (fraction)", hint: "Greater than 0, up to 1" },
];

export default function CalculatorPage() {
  const [values, setValues] = useState<FormValues>(DEFAULT_VALUES);
  const [errors, setErrors] = useState<FormErrors>({});
  const [loading, setLoading] = useState(false);
  const [apiError, setApiError] = useState<string | null>(null);
  const [result, setResult] = useState<CalculationResponse | null>(null);

  const set = (k: keyof FormValues, v: string) => setValues((p) => ({ ...p, [k]: v }));

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const { errors: errs, request } = validate(values);
    setErrors(errs);
    if (!request) {
      setApiError(null);
      document.getElementById(Object.keys(errs)[0])?.focus();
      return;
    }
    setLoading(true);
    setApiError(null);
    try {
      setResult(await calculate(request));
    } catch (err) {
      setResult(null);
      setApiError(err instanceof Error ? err.message : "Calculation failed.");
    } finally {
      setLoading(false);
    }
  }

  const field = (f: { key: NumKey; label: string; hint?: string }) => {
    const err = errors[f.key];
    const hintId = `${f.key}-hint`;
    const errId = `${f.key}-error`;
    return (
      <div key={f.key}>
        <Label htmlFor={f.key}>{f.label}</Label>
        <Input
          id={f.key}
          name={f.key}
          type="number"
          inputMode="decimal"
          step="any"
          value={values[f.key]}
          onChange={(e) => set(f.key, e.target.value)}
          aria-invalid={err ? true : undefined}
          aria-describedby={err ? `${hintId} ${errId}` : hintId}
        />
        {f.hint && <p id={hintId} className="mt-1 text-xs text-slate-400">{f.hint}</p>}
        {err && <p id={errId} className="mt-1 text-xs text-red-300">{err}</p>}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Borewell hydraulic analysis</h1>
        <p className="mt-1 text-sm text-slate-300">Calculate total dynamic head and motor power for a borewell pump.</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-[380px_1fr]">
        <Card className="h-fit">
          <form onSubmit={onSubmit} noValidate className="space-y-4">
            {REQUIRED.slice(0, 7).map((f) =>
              f.key === "flow_rate" ? (
                <div key="flow" className="grid grid-cols-[1fr_auto] gap-2">
                  {field({ ...f, label: "Flow rate (value)" })}
                  <div className="w-32">
                    <Label htmlFor="flow_rate_unit">Unit</Label>
                    <Select id="flow_rate_unit" value={values.flow_rate_unit} onChange={(e) => set("flow_rate_unit", e.target.value)}>
                      <option value="m3_per_h">m³/h</option>
                      <option value="l_per_min">L/min</option>
                      <option value="l_per_s">L/s</option>
                      <option value="m3_per_s">m³/s</option>
                    </Select>
                  </div>
                </div>
              ) : (
                field(f)
              ),
            )}
            <div>
              <Label htmlFor="pipe_material">Pipe material</Label>
              <Select id="pipe_material" value={values.pipe_material} onChange={(e) => set("pipe_material", e.target.value)}>
                <option value="pvc">PVC</option>
                <option value="hdpe">HDPE</option>
                <option value="gi">GI (galvanised iron)</option>
                <option value="steel">Steel</option>
                <option value="cast_iron">Cast iron</option>
              </Select>
            </div>

            <details className="rounded-md border border-line p-3" open={Object.keys(errors).some((k) => ADVANCED.some((a) => a.key === k))}>
              <summary className="cursor-pointer text-sm font-semibold text-aqua focus-visible:outline-2 focus-visible:outline-aqua">
                Advanced assumptions
              </summary>
              <div className="mt-3 space-y-4">{ADVANCED.map(field)}</div>
            </details>

            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? "Calculating..." : "Calculate"}
            </Button>
            {Object.keys(errors).length > 0 && (
              <p role="alert" className="text-sm text-red-300">Please fix the highlighted fields.</p>
            )}
          </form>
        </Card>

        <div className="min-w-0 space-y-6" aria-live="polite">
          {loading && <Alert>Running hydraulic calculation...</Alert>}
          {apiError && <Alert variant="error">{apiError}</Alert>}
          {!result && !loading && !apiError && (
            <Card className="text-center text-slate-300">
              <p className="font-medium text-white">No analysis yet</p>
              <p className="mt-1 text-sm">Fill in the borewell details and choose Calculate to see head, power and a cross-section.</p>
            </Card>
          )}
          {result && (
            <>
              <Results r={result} />
              <ExplainPanel key={JSON.stringify(result)} calculation={result} />
            </>
          )}
        </div>
      </div>
    </div>
  );
}

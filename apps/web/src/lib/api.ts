export const API_BASE_URL = (
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000"
).replace(/\/$/, "");

export type FlowUnit = "m3_per_h" | "l_per_min" | "l_per_s" | "m3_per_s";
export type PipeMaterial = "pvc" | "hdpe" | "gi" | "steel" | "cast_iron";
export type Audience = "farmer" | "dealer" | "technician";

export interface HealthResponse {
  status: string;
  service: string;
  version: string;
}

export interface CalculationRequest {
  borewell_depth_m: number;
  static_water_level_m: number;
  pumping_water_level_m: number;
  pump_setting_depth_m?: number;
  delivery_height_m: number;
  horizontal_pipe_length_m: number;
  pipe_internal_diameter_mm: number;
  flow_rate: number;
  flow_rate_unit?: FlowUnit;
  pipe_material?: PipeMaterial;
  minor_loss_fraction?: number;
  residual_pressure_head_m?: number;
  pump_efficiency?: number;
  motor_efficiency?: number;
}

export interface CalculationResponse {
  methodology_version: string;
  levels: {
    borewell_depth_m: number;
    static_water_level_m: number;
    pumping_water_level_m: number;
    pump_setting_depth_m: number;
    drawdown_m: number;
    delivery_elevation_m: number;
  };
  head: {
    static_head_m: number;
    total_static_lift_m: number;
    pipe_friction_loss_m: number;
    minor_loss_m: number;
    total_friction_loss_m: number;
    residual_pressure_head_m: number;
    total_dynamic_head_m: number;
  };
  tdh_breakdown: { key: string; label: string; value_m: number }[];
  pipe: {
    material: string;
    roughness_mm: number;
    internal_diameter_m: number;
    riser_length_m: number;
    total_length_m: number;
    velocity_m_s: number;
    reynolds_number: number;
    flow_regime: "laminar" | "transitional" | "turbulent";
    friction_factor: number;
  };
  flow: {
    m3_per_s: number;
    m3_per_h: number;
    l_per_s: number;
    l_per_min: number;
  };
  power: {
    hydraulic_power_kw: number;
    shaft_power_kw: number;
    input_power_kw: number;
    input_power_hp: number;
    pump_efficiency: number;
    motor_efficiency: number;
    overall_efficiency: number;
  };
  assumptions: string[];
  warnings: string[];
  disclaimer: string;
}

export interface ExplainRequest {
  calculation: CalculationResponse;
  audience: Audience;
  question?: string;
}

export interface ExplainResponse {
  provider: string;
  summary: string;
  key_points: string[];
  assumptions: string[];
  follow_up_questions: string[];
  disclaimer: string;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public kind: "network" | "validation" | "server",
    public status?: number,
  ) {
    super(message);
  }
}

const FIELD_LABELS: Record<string, string> = {
  borewell_depth_m: "Borewell depth",
  static_water_level_m: "Static water level",
  pumping_water_level_m: "Pumping water level",
  pump_setting_depth_m: "Pump setting depth",
  delivery_height_m: "Delivery height",
  horizontal_pipe_length_m: "Horizontal pipe length",
  pipe_internal_diameter_mm: "Pipe internal diameter",
  flow_rate: "Flow rate",
  flow_rate_unit: "Flow rate unit",
  pipe_material: "Pipe material",
  minor_loss_fraction: "Fittings allowance",
  residual_pressure_head_m: "Residual pressure head",
  pump_efficiency: "Pump efficiency",
  motor_efficiency: "Motor efficiency",
  question: "Question",
  audience: "Audience",
};

function formatDetail(detail: unknown): string {
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    const parts = detail.map((d) => {
      if (!d || typeof d !== "object") return String(d);
      const { loc, msg } = d as { loc?: unknown[]; msg?: string };
      const field = Array.isArray(loc) ? String(loc[loc.length - 1] ?? "") : "";
      const label = FIELD_LABELS[field] ?? field;
      return label ? `${label}: ${msg ?? "invalid value"}` : (msg ?? "Invalid value");
    });
    return parts.join("; ");
  }
  return "The request was rejected by the server.";
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      ...init,
      headers: { "Content-Type": "application/json", ...init?.headers },
    });
  } catch {
    throw new ApiError(
      `Could not reach the AquaOS API at ${API_BASE_URL}. Check that the backend is running.`,
      "network",
    );
  }
  if (!res.ok) {
    let detail: unknown;
    try {
      detail = (await res.json()).detail;
    } catch {
      /* non-JSON body */
    }
    if (res.status === 422) {
      throw new ApiError(formatDetail(detail), "validation", 422);
    }
    throw new ApiError(
      typeof detail === "string" ? detail : `The server returned an error (HTTP ${res.status}).`,
      "server",
      res.status,
    );
  }
  return (await res.json()) as T;
}

export const getHealth = () => request<HealthResponse>("/api/v1/health");

export const calculate = (body: CalculationRequest) =>
  request<CalculationResponse>("/api/v1/hydraulics/calculate", {
    method: "POST",
    body: JSON.stringify(body),
  });

export const explain = (body: ExplainRequest) =>
  request<ExplainResponse>("/api/v1/advisor/explain", {
    method: "POST",
    body: JSON.stringify(body),
  });

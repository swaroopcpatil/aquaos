import type { CalculationRequest, FlowUnit, PipeMaterial } from "./api";

export type FormValues = {
  borewell_depth_m: string;
  static_water_level_m: string;
  pumping_water_level_m: string;
  pump_setting_depth_m: string;
  delivery_height_m: string;
  horizontal_pipe_length_m: string;
  pipe_internal_diameter_mm: string;
  flow_rate: string;
  flow_rate_unit: FlowUnit;
  pipe_material: PipeMaterial;
  minor_loss_fraction: string;
  residual_pressure_head_m: string;
  pump_efficiency: string;
  motor_efficiency: string;
};

export type FormErrors = Partial<Record<keyof FormValues, string>>;

export const DEFAULT_VALUES: FormValues = {
  borewell_depth_m: "",
  static_water_level_m: "",
  pumping_water_level_m: "",
  pump_setting_depth_m: "",
  delivery_height_m: "",
  horizontal_pipe_length_m: "",
  pipe_internal_diameter_mm: "",
  flow_rate: "",
  flow_rate_unit: "m3_per_h",
  pipe_material: "pvc",
  minor_loss_fraction: "0.10",
  residual_pressure_head_m: "0",
  pump_efficiency: "0.60",
  motor_efficiency: "0.80",
};

function parse(raw: string): number | null {
  if (raw.trim() === "") return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : NaN;
}

type Rule = { min?: number; minExclusive?: boolean; max?: number };

/** Pure validation mirroring the API contract. Returns errors and, if valid, the request body. */
export function validate(v: FormValues): {
  errors: FormErrors;
  request: CalculationRequest | null;
} {
  const errors: FormErrors = {};
  const nums: Partial<Record<keyof FormValues, number>> = {};

  const check = (key: keyof FormValues, required: boolean, rule: Rule) => {
    const n = parse(v[key] as string);
    if (n === null) {
      if (required) errors[key] = "This field is required.";
      return;
    }
    if (Number.isNaN(n)) {
      errors[key] = "Enter a valid number.";
      return;
    }
    if (rule.min !== undefined && (rule.minExclusive ? n <= rule.min : n < rule.min)) {
      errors[key] = rule.minExclusive
        ? `Must be greater than ${rule.min}.`
        : `Must be at least ${rule.min}.`;
      return;
    }
    if (rule.max !== undefined && n > rule.max) {
      errors[key] = `Must be at most ${rule.max}.`;
      return;
    }
    nums[key] = n;
  };

  check("borewell_depth_m", true, { min: 0, minExclusive: true, max: 2000 });
  check("static_water_level_m", true, { min: 0 });
  check("pumping_water_level_m", true, { min: 0 });
  check("pump_setting_depth_m", false, { min: 0 });
  check("delivery_height_m", true, { min: 0, max: 1000 });
  check("horizontal_pipe_length_m", true, { min: 0, max: 50000 });
  check("pipe_internal_diameter_mm", true, { min: 10, max: 1000 });
  check("flow_rate", true, { min: 0, minExclusive: true });
  check("minor_loss_fraction", true, { min: 0, max: 1 });
  check("residual_pressure_head_m", true, { min: 0, max: 200 });
  check("pump_efficiency", true, { min: 0, minExclusive: true, max: 1 });
  check("motor_efficiency", true, { min: 0, minExclusive: true, max: 1 });

  const { borewell_depth_m: depth, static_water_level_m: stat, pumping_water_level_m: pump } = nums;
  const setting = nums.pump_setting_depth_m;

  if (pump !== undefined && stat !== undefined && pump < stat) {
    errors.pumping_water_level_m = "Pumping level must be at or below the static water level.";
  }
  if (!errors.pumping_water_level_m && pump !== undefined && depth !== undefined && pump >= depth) {
    errors.pumping_water_level_m = "Pumping level must be above (less than) the borewell depth.";
  }
  if (!errors.static_water_level_m && stat !== undefined && depth !== undefined && stat >= depth) {
    errors.static_water_level_m = "Static water level must be above the borewell depth.";
  }
  if (setting !== undefined) {
    if (pump !== undefined && setting < pump) {
      errors.pump_setting_depth_m = "Pump setting depth must be at or below the pumping water level.";
    } else if (depth !== undefined && setting > depth) {
      errors.pump_setting_depth_m = "Pump setting depth cannot exceed the borewell depth.";
    }
  }

  if (Object.keys(errors).length > 0) return { errors, request: null };

  const req: CalculationRequest = {
    borewell_depth_m: nums.borewell_depth_m!,
    static_water_level_m: nums.static_water_level_m!,
    pumping_water_level_m: nums.pumping_water_level_m!,
    delivery_height_m: nums.delivery_height_m!,
    horizontal_pipe_length_m: nums.horizontal_pipe_length_m!,
    pipe_internal_diameter_mm: nums.pipe_internal_diameter_mm!,
    flow_rate: nums.flow_rate!,
    flow_rate_unit: v.flow_rate_unit,
    pipe_material: v.pipe_material,
    minor_loss_fraction: nums.minor_loss_fraction!,
    residual_pressure_head_m: nums.residual_pressure_head_m!,
    pump_efficiency: nums.pump_efficiency!,
    motor_efficiency: nums.motor_efficiency!,
  };
  if (setting !== undefined) req.pump_setting_depth_m = setting;
  return { errors, request: req };
}

export const QUESTION_MAX = 500;

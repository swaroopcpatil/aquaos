import json

from app.ai.context import CALC_END, CALC_START
from app.ai.provider import ModelProvider, ProviderError

DISCLAIMER = (
    "This is an explanation of a calculation, not a pump selection or installation guarantee. "
    "Confirm with a qualified technician and the pump manufacturer's curves before buying."
)


def _num(d: dict, key: str, digits: int = 2):
    """Read a number for display. Rounding is presentation only; the source value is unchanged."""
    v = d.get(key)
    return round(v, digits) if isinstance(v, int | float) else None


class MockProvider(ModelProvider):
    name = "mock"

    def generate(self, system: str, user: str) -> str:
        try:
            audience = user.split("AUDIENCE:", 1)[1].splitlines()[0].strip()
            raw = user.split(CALC_START, 1)[1].split(CALC_END, 1)[0]
            calc = json.loads(raw)
        except (IndexError, ValueError) as e:
            raise ProviderError("mock provider could not read calculation") from e

        head = calc.get("head", {})
        flow = calc.get("flow", {})
        power = calc.get("power", {})
        tdh = _num(head, "total_dynamic_head_m")
        q = _num(flow, "m3_per_h")
        hp = _num(power, "input_power_hp")
        kw = _num(power, "input_power_kw")
        fric = _num(head, "total_friction_loss_m")

        flow_txt = f"{q} m3/h" if q is not None else "the requested flow"
        power_txt = (
            f"{kw} kW ({hp} HP) of electrical input" if kw is not None and hp is not None
            else f"{kw} kW of electrical input" if kw is not None else "the calculated power"
        )
        if audience == "dealer":
            summary = (f"To deliver {flow_txt} the pump must produce a total dynamic head of "
                       f"{tdh} m. Size against that duty point and expect about {power_txt}.")
        elif audience == "technician":
            summary = (f"Duty point: {flow_txt} at TDH {tdh} m; friction loss "
                       f"{fric} m; calculated input power {power_txt}.")
        else:
            summary = (f"Your pump needs to lift and push water against about {tdh} m of "
                       f"head to deliver {flow_txt}. That needs {power_txt}.")

        points = [f"Total dynamic head: {tdh} m."]
        if fric is not None:
            points.append(f"Pipe and fitting friction loss: {fric} m.")
        if q is not None:
            points.append(f"Flow rate: {q} m3/h.")
        if kw is not None:
            points.append(f"Input power: {kw} kW.")
        if hp is not None:
            points.append(f"Input power in HP: {hp} HP.")
        if audience == "technician":
            pipe = calc.get("pipe", {})
            v, f = _num(pipe, "velocity_m_s"), _num(pipe, "friction_factor", 4)
            if v is not None:
                points.append(f"Pipe velocity: {v} m/s.")
            if f is not None:
                points.append(f"Darcy friction factor: {f}.")

        assumptions = [str(a) for a in calc.get("assumptions", []) if isinstance(a, str)][:5]
        follow = [
            "What is the pump's rated efficiency at this duty point?",
            "Can a larger pipe diameter reduce the friction loss?",
        ]
        return json.dumps({
            "summary": summary,
            "key_points": points,
            "assumptions": assumptions,
            "follow_up_questions": follow,
            "disclaimer": DISCLAIMER,
        })

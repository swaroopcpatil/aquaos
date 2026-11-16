from typing import Literal

from pydantic import BaseModel, Field, field_validator


class ExplainRequest(BaseModel):
    calculation: dict
    audience: Literal["farmer", "dealer", "technician"] = "farmer"
    question: str | None = Field(default=None, max_length=500)

    @field_validator("calculation")
    @classmethod
    def _check_calc(cls, v: dict) -> dict:
        head, flow, power = v.get("head"), v.get("flow"), v.get("power")
        tdh = head.get("total_dynamic_head_m") if isinstance(head, dict) else None
        if not isinstance(tdh, int | float):
            raise ValueError("calculation.head.total_dynamic_head_m is required")  # noqa: TRY004
        if not isinstance(flow, dict) or not flow:
            raise ValueError("calculation.flow is required")
        if not isinstance(power, dict) or not power:
            raise ValueError("calculation.power is required")
        return v


class ExplainResponse(BaseModel):
    provider: str
    summary: str
    key_points: list[str]
    assumptions: list[str]
    follow_up_questions: list[str]
    disclaimer: str


class ModelOutput(BaseModel):
    """What the model must return (provider name is added by the server)."""

    summary: str = Field(min_length=1)
    key_points: list[str]
    assumptions: list[str]
    follow_up_questions: list[str]
    disclaimer: str = Field(min_length=1)

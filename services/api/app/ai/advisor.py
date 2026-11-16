import json
import logging
import time

from pydantic import ValidationError

from app.ai.context import SYSTEM_PROMPT, build_user_prompt
from app.ai.factory import get_provider
from app.ai.schemas import ExplainRequest, ExplainResponse, ModelOutput

logger = logging.getLogger("aquaos.advisor")


class AdvisorError(Exception):
    """Provider failed or returned invalid output; routes map this to 503."""


def _strip_fences(text: str) -> str:
    t = text.strip()
    if t.startswith("```"):
        t = t.split("\n", 1)[-1].rsplit("```", 1)[0]
    return t.strip()


def explain(req: ExplainRequest) -> ExplainResponse:
    start = time.perf_counter()
    provider_name = "unknown"
    outcome = "error"
    try:
        provider = get_provider()
        provider_name = provider.name
        raw = provider.generate(
            SYSTEM_PROMPT, build_user_prompt(req.calculation, req.audience, req.question)
        )
        out = ModelOutput.model_validate(json.loads(_strip_fences(raw)))
        outcome = "ok"
        return ExplainResponse(provider=provider_name, **out.model_dump())
    except (ValueError, ValidationError, TypeError) as e:  # json errors are ValueError
        raise AdvisorError("AI provider returned invalid output") from e
    except Exception as e:
        raise AdvisorError("AI provider unavailable") from e
    finally:
        logger.info(
            "advisor run",
            extra={"ctx": {"provider": provider_name, "outcome": outcome,
                           "duration_ms": round((time.perf_counter() - start) * 1000, 1)}},
        )

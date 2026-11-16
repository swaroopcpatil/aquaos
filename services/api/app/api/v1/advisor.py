from fastapi import APIRouter, HTTPException

from app.ai.advisor import AdvisorError, explain
from app.ai.schemas import ExplainRequest, ExplainResponse

router = APIRouter(prefix="/advisor", tags=["advisor"])


@router.post("/explain", response_model=ExplainResponse)
def explain_route(req: ExplainRequest) -> ExplainResponse:
    try:
        return explain(req)
    except AdvisorError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e

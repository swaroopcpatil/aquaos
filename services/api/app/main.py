import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import setup_logging

logger = logging.getLogger("aquaos.api")


def create_app() -> FastAPI:
    setup_logging()
    settings = get_settings()
    app = FastAPI(title="AquaOS API", version=settings.APP_VERSION)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
    )

    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception) -> JSONResponse:
        logger.error("unhandled error", exc_info=exc, extra={"ctx": {"path": request.url.path}})
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})

    app.include_router(api_router, prefix="/api/v1")
    return app


app = create_app()

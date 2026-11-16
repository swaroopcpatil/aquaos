from fastapi import APIRouter

from app.api.v1 import advisor, health, hydraulics

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(advisor.router)
api_router.include_router(hydraulics.router)

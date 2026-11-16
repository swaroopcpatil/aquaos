from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_ENV: str = "development"
    APP_VERSION: str = "0.1.0"
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]
    AI_PROVIDER: str = "mock"
    AI_API_KEY: str | None = None
    AI_MODEL: str | None = None
    AI_TIMEOUT_SECONDS: float = 20
    AI_MAX_RETRIES: int = 1


@lru_cache
def get_settings() -> Settings:
    return Settings()

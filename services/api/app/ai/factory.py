from app.ai.anthropic_provider import AnthropicProvider
from app.ai.mock_provider import MockProvider
from app.ai.provider import ModelProvider, ProviderError
from app.core.config import get_settings


def get_provider() -> ModelProvider:
    s = get_settings()
    name = s.AI_PROVIDER.lower()
    if name == "mock":
        return MockProvider()
    if name == "anthropic":
        return AnthropicProvider(s.AI_API_KEY, s.AI_MODEL, s.AI_TIMEOUT_SECONDS, s.AI_MAX_RETRIES)
    raise ProviderError(f"unknown AI provider: {name}")

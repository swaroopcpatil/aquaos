import httpx

from app.ai.provider import ModelProvider, ProviderError

URL = "https://api.anthropic.com/v1/messages"
DEFAULT_MODEL = "claude-sonnet-4-5"


class AnthropicProvider(ModelProvider):
    name = "anthropic"

    def __init__(self, api_key: str | None, model: str | None, timeout: float, max_retries: int):
        if not api_key:
            raise ProviderError("AI_API_KEY is required for the anthropic provider")
        self.api_key = api_key
        self.model = model or DEFAULT_MODEL
        self.timeout = timeout
        self.max_retries = max(0, max_retries)

    def generate(self, system: str, user: str) -> str:
        body = {
            "model": self.model,
            "max_tokens": 1024,
            "system": system,
            "messages": [{"role": "user", "content": user}],
        }
        headers = {"x-api-key": self.api_key, "anthropic-version": "2023-06-01"}
        last: Exception | None = None
        for _ in range(self.max_retries + 1):
            try:
                r = httpx.post(URL, json=body, headers=headers, timeout=self.timeout)
                r.raise_for_status()
                return "".join(
                    b.get("text", "") for b in r.json().get("content", []) if b.get("type") == "text"
                )
            except (httpx.HTTPError, ValueError) as e:
                last = e
        raise ProviderError(f"anthropic request failed: {type(last).__name__}") from last

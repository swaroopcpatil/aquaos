from abc import ABC, abstractmethod


class ProviderError(Exception):
    """Raised when a provider call fails or times out."""


class ModelProvider(ABC):
    name: str = "provider"

    @abstractmethod
    def generate(self, system: str, user: str) -> str:
        """Return the model's raw text output (expected to be JSON)."""

"""Enrutador de LLM: prueba proveedores en orden y deja enfriar a los limitados por cuota."""

import logging
import threading
import time
from collections.abc import Callable, Sequence

from src.domain.exceptions import AllProvidersFailedError, RateLimitedError
from src.domain.interfaces.ports import LLMProvider

logger = logging.getLogger("talky.routing")

COOLING_DOWN = "en enfriamiento por límite de cuota"


class LLMRouter(LLMProvider):
    """LLMProvider compuesto: respaldo ante fallos y enfriamiento ante 429."""

    name = "router"

    def __init__(
        self,
        providers: Sequence[LLMProvider],
        cooldown_s: float = 60.0,
        clock: Callable[[], float] = time.monotonic,
    ):
        if not providers:
            raise ValueError("LLMRouter necesita al menos un proveedor")
        self._providers = list(providers)
        self._cooldown_s = cooldown_s
        self._clock = clock
        self._cooling_until: dict[int, float] = {}
        self._lock = threading.Lock()

    def _is_cooling_down(self, index: int) -> bool:
        with self._lock:
            return self._clock() < self._cooling_until.get(index, float("-inf"))

    def _start_cooldown(self, index: int, retry_after: float | None) -> None:
        seconds = retry_after if retry_after is not None else self._cooldown_s
        with self._lock:
            self._cooling_until[index] = self._clock() + seconds

    def complete_json(self, system: str, user: str) -> str:
        errors: dict[str, str] = {}
        for index, provider in enumerate(self._providers):
            if self._is_cooling_down(index):
                errors[provider.name] = COOLING_DOWN
                continue
            try:
                return provider.complete_json(system, user)
            except RateLimitedError as e:
                self._start_cooldown(index, e.retry_after)
                logger.warning("Proveedor %s limitado por cuota; entra en enfriamiento", provider.name)
                errors[provider.name] = str(e)
            except Exception as e:  # noqa: BLE001
                logger.warning("Proveedor %s falló (%s); se prueba el siguiente", provider.name, type(e).__name__)
                errors[provider.name] = str(e) or type(e).__name__
        raise AllProvidersFailedError(errors)

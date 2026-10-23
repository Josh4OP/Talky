"""T07 - Enrutador de LLM: respaldo ante fallos y enfriamiento ante 429.

Contrato: src/application/routing/llm_router.py
  LLMRouter(providers, cooldown_s=60.0, clock=time.monotonic)   # es un LLMProvider, name == "router"
  .complete_json(system, user) -> str
Excepciones (src/domain/exceptions): RateLimitedError(retry_after=None), ProviderError,
  AllProvidersFailedError(errors: dict[str, str])  # subclase de RuntimeError
"""

import pytest
from fakes import FakeLLM
from src.application.routing.llm_router import LLMRouter

from src.domain.exceptions import AllProvidersFailedError, ProviderError, RateLimitedError
from src.domain.interfaces.ports import LLMProvider


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


def test_is_a_provider_named_router():
    router = LLMRouter([FakeLLM("a")])
    assert isinstance(router, LLMProvider)
    assert router.name == "router"


def test_requires_at_least_one_provider():
    with pytest.raises(ValueError):
        LLMRouter([])


def test_uses_the_first_provider_when_it_works():
    a, b = FakeLLM("a"), FakeLLM("b")
    LLMRouter([a, b]).complete_json("system", "user")
    assert a.calls == ["analysis"] and b.calls == []


def test_falls_back_on_provider_error():
    a = FakeLLM("a", fail_analysis=ProviderError("boom"))
    b = FakeLLM("b")
    assert "organizacion" in LLMRouter([a, b]).complete_json("system", "user")
    assert b.calls == ["analysis"]


def test_falls_back_on_unexpected_exceptions():
    a = FakeLLM("a", fail_analysis=ValueError("respuesta vacía"))
    b = FakeLLM("b")
    LLMRouter([a, b]).complete_json("system", "user")
    assert b.calls == ["analysis"]


def test_rate_limited_provider_cools_down_and_is_skipped():
    clock = Clock()
    a = FakeLLM("a", fail_analysis=RateLimitedError())
    b = FakeLLM("b")
    router = LLMRouter([a, b], cooldown_s=60, clock=clock)

    router.complete_json("s", "u")
    assert len(a.calls) == 1

    clock.now += 1
    router.complete_json("s", "u")
    assert len(a.calls) == 1, "durante el enfriamiento no se vuelve a llamar al proveedor limitado"
    assert len(b.calls) == 2


def test_provider_is_retried_after_cooldown():
    clock = Clock()
    a = FakeLLM("a", fail_analysis=RateLimitedError())
    b = FakeLLM("b")
    router = LLMRouter([a, b], cooldown_s=60, clock=clock)
    router.complete_json("s", "u")
    clock.now += 61
    router.complete_json("s", "u")
    assert len(a.calls) == 2


def test_retry_after_overrides_the_default_cooldown():
    clock = Clock()
    a = FakeLLM("a", fail_analysis=RateLimitedError(retry_after=120))
    b = FakeLLM("b")
    router = LLMRouter([a, b], cooldown_s=60, clock=clock)
    router.complete_json("s", "u")
    clock.now += 100
    router.complete_json("s", "u")
    assert len(a.calls) == 1


def test_generic_errors_do_not_trigger_cooldown():
    a = FakeLLM("a", fail_analysis=ProviderError("boom"))
    b = FakeLLM("b")
    router = LLMRouter([a, b])
    router.complete_json("s", "u")
    router.complete_json("s", "u")
    assert len(a.calls) == 2


def test_all_failing_raises_with_every_error():
    a = FakeLLM("a", fail_analysis=ProviderError("falla a"))
    b = FakeLLM("b", fail_analysis=RateLimitedError())
    with pytest.raises(AllProvidersFailedError) as exc:
        LLMRouter([a, b]).complete_json("s", "u")
    assert set(exc.value.errors) == {"a", "b"}
    assert isinstance(exc.value, RuntimeError)


def test_all_cooling_down_fails_fast_without_calling_anyone():
    clock = Clock()
    a = FakeLLM("a", fail_analysis=RateLimitedError())
    router = LLMRouter([a], cooldown_s=60, clock=clock)
    with pytest.raises(AllProvidersFailedError):
        router.complete_json("s", "u")
    clock.now += 1
    with pytest.raises(AllProvidersFailedError):
        router.complete_json("s", "u")
    assert len(a.calls) == 1

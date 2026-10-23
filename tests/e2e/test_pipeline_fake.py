"""T14 - Pipeline completo con dobles (sin red, sin modelos, sin claves).

Verifica el contrato de la respuesta de POST /analyses (context/07-api-contract.md) y la
degradación elegante: cualquier etapa opcional que falle NO tumba el análisis.
"""

import pytest
from fakes import (
    INVENTED_QUOTE,
    VALID_QUOTE,
    FakeEventClassifier,
    FakeLLM,
    ScriptedEmbedder,
    post_audio,
)
from src.domain.entities.events import AcousticEvent

from src.domain.exceptions import RateLimitedError

pytest.importorskip("fastapi")

EVENTS = [
    AcousticEvent(start=0.0, end=0.4, label="filler", confidence=0.9),  # coincide con "Eh," de la muestra
    AcousticEvent(start=40.0, end=41.0, label="hum", confidence=0.8),
]


def _embedder():
    return ScriptedEmbedder([[1.0, 0.0], [0.8, 0.6], [0.6, 0.8], [0.0, 1.0]], cycle=True)


def test_full_response_contract(client_factory):
    client, _ = client_factory(embedder=_embedder(), event_classifier=FakeEventClassifier(EVENTS))
    body = post_audio(client).json()

    # métricas objetivas
    assert body["ppm"] > 0 and body["duracion_s"] > 0
    assert body["muletillas"].get("eh", 0) >= 1 and body["muletillas"].get("mmm", 0) >= 1
    assert body["muletillas_por_minuto"] > 0
    assert body["pausas"]["pausas_largas"] >= 1
    assert body["transcripcion_recortada"] is False

    # etapas opcionales activas
    assert body["coherencia"]["windows"] >= 2
    assert body["eventos_acusticos"]["muletillas"] and body["eventos_acusticos"]["tarareos"]
    assert body["eventos_acusticos"]["muletillas"][0]["source"] == "both"

    # LLM, síntesis y verificación
    assert set(body["modelos_usados"]) == {"a", "b"}
    assert body["puntajes"]["organizacion"]["mediana"] == 7
    assert body["sintesis"]["resumen"]
    assert body["advertencias"] == []


def test_unverified_quotes_are_discarded_and_counted(client_factory):
    client, _ = client_factory()
    body = post_audio(client).json()
    assert body["verificacion"]["descartadas"] == 2  # 1 cita inventada x 2 modelos
    assert body["verificacion"]["tasa"] == pytest.approx(0.5)
    citas = [e["cita"] for e in body["evidencias"]]
    assert citas == [VALID_QUOTE]  # verificadas y sin duplicados
    assert INVENTED_QUOTE not in str(body["sintesis"]) + str(citas)


def test_verifier_can_be_disabled(client_factory):
    client, _ = client_factory(settings={"enable_verifier": False})
    body = post_audio(client).json()
    assert body["verificacion"] is None


def test_optional_stages_are_off_by_default(client_factory):
    client, _ = client_factory()
    body = post_audio(client).json()
    assert body["coherencia"] is None
    assert body["eventos_acusticos"] is None


def test_event_classifier_failure_degrades_with_a_warning(client_factory):
    client, _ = client_factory(event_classifier=FakeEventClassifier(error=RuntimeError("modelo corrupto")))
    r = post_audio(client)
    assert r.status_code == 201
    body = r.json()
    assert body["eventos_acusticos"] is None
    assert any("evento" in w.lower() for w in body["advertencias"])


def test_embedder_failure_degrades_with_a_warning(client_factory):
    client, _ = client_factory(embedder=ScriptedEmbedder([[1, 0]], error=RuntimeError("sin memoria")))
    r = post_audio(client)
    assert r.status_code == 201
    body = r.json()
    assert body["coherencia"] is None
    assert any("coherencia" in w.lower() for w in body["advertencias"])


def test_judge_failure_falls_back_to_another_provider(client_factory):
    # "gemini" es el juez por defecto, pero su síntesis está limitada por cuota.
    providers = [FakeLLM("a"), FakeLLM("gemini", fail_synthesis=RateLimitedError())]
    client, _ = client_factory(providers=providers)
    body = post_audio(client).json()
    assert body["sintesis"]["resumen"] == "resumen-a"


def test_one_failing_analyst_does_not_break_the_response(client_factory):
    providers = [FakeLLM("a"), FakeLLM("b", fail_analysis=RuntimeError("timeout"))]
    client, _ = client_factory(providers=providers)
    body = post_audio(client).json()
    assert body["modelos_usados"] == ["a"]
    assert "b" in body["modelos_fallidos"]


def test_result_is_persisted_and_identical_when_fetched(client_factory):
    client, _ = client_factory(embedder=_embedder())
    created = post_audio(client, user="ana").json()
    fetched = client.get(f"/analyses/{created['id']}", headers={"X-User-Id": "ana"}).json()
    assert fetched == created

"""T15 - Reglas HTTP que no cubren las pruebas de aceptación.

Contrato: harness/context/07-api-contract.md y harness/agent/rules/security-privacy.md
  - El temporal también se borra cuando la subida pasa del límite (se corta mientras se lee).
  - 503 y 422 genéricos no exponen detalles técnicos de proveedores ni excepciones.
  - El nombre de archivo guardado no conserva rutas; la extensión no distingue mayúsculas.
  - La identidad se valida antes que el formato; offset negativo es 422.
  - /health informa las advertencias de arranque.
"""

import tempfile

import pytest
from fakes import FakeLLM, FakeTranscriber, post_audio

from src.domain.exceptions import ProviderError

pytest.importorskip("fastapi")


def test_oversized_upload_leaves_no_temporary_file(client_factory, tmp_path, monkeypatch):
    temp_dir = tmp_path / "tmp"
    temp_dir.mkdir()
    monkeypatch.setattr(tempfile, "tempdir", str(temp_dir))
    client, _ = client_factory(settings={"max_upload_mb": 1})
    assert post_audio(client, content=b"\0" * (3 * 1024 * 1024)).status_code == 413
    assert list(temp_dir.iterdir()) == []


def test_service_unavailable_message_hides_provider_details(client_factory):
    providers = [FakeLLM("a", fail_analysis=ProviderError("clave gsk_123 rechazada"))]
    client, _ = client_factory(providers=providers)
    r = post_audio(client)
    assert r.status_code == 503
    assert "gsk_123" not in r.text and "ProviderError" not in r.text


def test_generic_value_errors_are_422_without_internals(client_factory):
    client, _ = client_factory(transcriber=FakeTranscriber(error=ValueError("could not convert string to float")))
    r = post_audio(client)
    assert r.status_code == 422
    assert "convert" not in r.json()["detail"]


def test_stored_filename_has_no_path(client_factory):
    client, _ = client_factory()
    post_audio(client, user="ana", filename="../../secreto/charla.wav")
    items = client.get("/analyses", headers={"X-User-Id": "ana"}).json()["items"]
    assert items[0]["filename"] == "charla.wav"


def test_extension_check_ignores_case(client_factory):
    client, _ = client_factory()
    assert post_audio(client, filename="CHARLA.WAV").status_code == 201


def test_identity_is_checked_before_the_format(client_factory):
    client, _ = client_factory()
    assert post_audio(client, user=None, filename="notas.txt", content=b"x").status_code == 401


def test_negative_offset_is_rejected(client_factory):
    client, _ = client_factory()
    assert client.get("/analyses?offset=-1", headers={"X-User-Id": "ana"}).status_code == 422


def test_health_reports_startup_warnings(client_factory, tmp_path):
    client, container = client_factory(
        settings={"enable_event_classifier": True, "event_model_path": str(tmp_path / "no-existe.joblib")}
    )
    body = client.get("/health").json()
    assert body["advertencias"] == container.warnings and body["advertencias"]

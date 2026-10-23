"""T05/T14 - Contrato HTTP de la API v1 (ver context/07-api-contract.md).

Contrato: src/presentation/app.py -> create_app(container) -> FastAPI
  GET    /health
  POST   /analyses            multipart `file`, cabecera X-User-Id            -> 201
  GET    /analyses?limit&offset                                              -> 200 {"items", "total", "limit", "offset"}
  GET    /analyses/{id}                                                      -> 200 | 404
  DELETE /analyses/{id}                                                      -> 204 | 404
Errores: 400 formato/identidad inválidos, 401 sin identidad, 413 archivo grande,
         422 audio inválido o sin voz, 503 ningún proveedor respondió.
"""

import os

import pytest
from fakes import FakeLLM, FakeTranscriber, post_audio

from src.domain.exceptions import InvalidAudioError, ProviderError
from src.domain.interfaces.ports import Transcription

pytest.importorskip("fastapi")


def test_health(client_factory):
    client, _ = client_factory()
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert set(body["features"]) == {"event_classifier", "text_embeddings", "verifier"}
    assert body["features"]["verifier"] is True


class TestIdentity:
    def test_missing_user_header_is_401(self, client_factory):
        client, _ = client_factory()
        assert post_audio(client, user=None).status_code == 401
        assert client.get("/analyses").status_code == 401

    @pytest.mark.parametrize("bad", ["a b!", "x" * 65, "../etc"])
    def test_malformed_user_header_is_400(self, client_factory, bad):
        client, _ = client_factory()
        assert post_audio(client, user=bad).status_code == 400

    def test_email_like_identifiers_are_accepted(self, client_factory):
        client, _ = client_factory()
        assert post_audio(client, user="ana.perez@utb.edu.co").status_code == 201


class TestCreateAnalysis:
    def test_returns_201_with_id_and_result(self, client_factory):
        client, _ = client_factory()
        r = post_audio(client)
        assert r.status_code == 201
        body = r.json()
        assert body["id"] and body["creado_en"]
        for key in ("duracion_s", "ppm", "pausas", "muletillas", "sintesis", "puntajes", "advertencias"):
            assert key in body

    def test_unsupported_extension_is_400(self, client_factory):
        client, _ = client_factory()
        r = post_audio(client, filename="notas.txt", content=b"hola")
        assert r.status_code == 400
        assert "no compatible" in r.json()["detail"].lower()

    def test_file_too_large_is_413(self, client_factory):
        client, _ = client_factory(settings={"max_upload_mb": 1})
        r = post_audio(client, content=b"\0" * (2 * 1024 * 1024))
        assert r.status_code == 413

    def test_temp_audio_is_deleted_after_the_request(self, client_factory):
        transcriber = FakeTranscriber()
        client, _ = client_factory(transcriber=transcriber)
        post_audio(client)
        assert transcriber.paths and not os.path.exists(transcriber.paths[0])

    def test_audio_without_speech_is_422(self, client_factory):
        empty = Transcription(text="  ", segments=[], duration=3.0, words=[])
        client, _ = client_factory(transcriber=FakeTranscriber(empty))
        r = post_audio(client)
        assert r.status_code == 422
        assert "voz" in r.json()["detail"].lower()

    def test_invalid_audio_is_422(self, client_factory):
        client, _ = client_factory(transcriber=FakeTranscriber(error=InvalidAudioError("archivo corrupto")))
        assert post_audio(client).status_code == 422

    def test_all_llm_providers_failing_is_503(self, client_factory):
        providers = [FakeLLM("a", fail_analysis=ProviderError("x")), FakeLLM("b", fail_analysis=ProviderError("y"))]
        client, _ = client_factory(providers=providers)
        assert post_audio(client).status_code == 503


class TestHistory:
    def test_list_get_and_delete(self, client_factory):
        client, _ = client_factory()
        created = post_audio(client, user="ana", filename="uno.wav").json()
        post_audio(client, user="ana", filename="dos.wav")

        listing = client.get("/analyses", headers={"X-User-Id": "ana"}).json()
        assert listing["total"] == 2
        assert [i["filename"] for i in listing["items"]] == ["dos.wav", "uno.wav"]
        assert {"id", "created_at", "duracion_s", "ppm", "total_muletillas"} <= set(listing["items"][0])

        detail = client.get(f"/analyses/{created['id']}", headers={"X-User-Id": "ana"})
        assert detail.status_code == 200 and detail.json()["id"] == created["id"]

        assert client.delete(f"/analyses/{created['id']}", headers={"X-User-Id": "ana"}).status_code == 204
        assert client.get(f"/analyses/{created['id']}", headers={"X-User-Id": "ana"}).status_code == 404

    def test_pagination(self, client_factory):
        client, _ = client_factory()
        for i in range(3):
            post_audio(client, user="ana", filename=f"{i}.wav")
        page = client.get("/analyses?limit=1&offset=1", headers={"X-User-Id": "ana"}).json()
        assert len(page["items"]) == 1 and page["total"] == 3
        assert (page["limit"], page["offset"]) == (1, 1)

    def test_other_users_cannot_see_or_delete_my_results(self, client_factory):
        client, _ = client_factory()
        aid = post_audio(client, user="ana").json()["id"]
        assert client.get(f"/analyses/{aid}", headers={"X-User-Id": "beto"}).status_code == 404
        assert client.delete(f"/analyses/{aid}", headers={"X-User-Id": "beto"}).status_code == 404
        assert client.get("/analyses", headers={"X-User-Id": "beto"}).json()["total"] == 0

    def test_unknown_id_is_404(self, client_factory):
        client, _ = client_factory()
        assert client.get("/analyses/no-existe", headers={"X-User-Id": "ana"}).status_code == 404

    def test_limit_is_bounded(self, client_factory):
        client, _ = client_factory()
        assert client.get("/analyses?limit=1000", headers={"X-User-Id": "ana"}).status_code == 422


def test_cors_uses_configured_origins(client_factory):
    client, _ = client_factory(settings={"cors_origins": ("http://localhost:3000",)})
    r = client.options(
        "/analyses",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "x-user-id",
        },
    )
    assert r.headers.get("access-control-allow-origin") == "http://localhost:3000"
    assert "x-user-id" in r.headers.get("access-control-allow-headers", "").lower()

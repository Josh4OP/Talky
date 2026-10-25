"""Contrato HTTP de la sesión con JWT de dispositivo (T19).

- Modo `jwt`: `POST /auth/token` responde 201 con `access_token`, `token_type="bearer"` y `expires_in`; el
  sujeto lo genera el servidor (`talky-` + 32 hexadecimales). `POST /auth/refresh` exige un Bearer válido y
  devuelve otro token del mismo sujeto.
- Modo `jwt`: las rutas de `/analyses` exigen `Authorization: Bearer`. Sin token o con token inválido
  responden 401 con `WWW-Authenticate: Bearer`; `X-User-Id` se ignora.
- Cada token solo ve sus propios análisis.
- Modo `header` (por defecto): las rutas `/auth/*` no existen.
"""

import re

import pytest
from fakes import make_wav_bytes, post_audio

pytest.importorskip("jwt")

SECRET = "s" * 32
JWT_SETTINGS = {"auth_mode": "jwt", "jwt_secret": SECRET}


@pytest.fixture
def jwt_app(client_factory):
    return client_factory(settings=JWT_SETTINGS)


@pytest.fixture
def jwt_client(jwt_app):
    return jwt_app[0]


@pytest.fixture
def verify(jwt_app):
    return jwt_app[1].token_service.verify


def _token(client) -> str:
    return client.post("/auth/token").json()["access_token"]


def _bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _upload(client, headers: dict):
    files = {"file": ("charla.wav", make_wav_bytes(1.0), "audio/wav")}
    return client.post("/analyses", files=files, headers=headers)


def test_token_endpoint_issues_a_bearer_token(jwt_client):
    response = jwt_client.post("/auth/token")
    body = response.json()
    assert (response.status_code, body["token_type"], body["expires_in"]) == (201, "bearer", 30 * 86400)


def test_token_subject_is_generated_by_the_server(jwt_client, verify):
    subject = verify(_token(jwt_client))
    assert re.fullmatch(r"talky-[0-9a-f]{32}", subject)


def test_each_token_request_creates_a_new_identity(jwt_client, verify):
    assert verify(_token(jwt_client)) != verify(_token(jwt_client))


def test_refresh_keeps_the_same_subject(jwt_client, verify):
    token = _token(jwt_client)
    refreshed = jwt_client.post("/auth/refresh", headers=_bearer(token)).json()["access_token"]
    assert verify(refreshed) == verify(token)


def test_refresh_without_token_is_unauthorized(jwt_client):
    assert jwt_client.post("/auth/refresh").status_code == 401


def test_refresh_with_invalid_token_is_unauthorized(jwt_client):
    assert jwt_client.post("/auth/refresh", headers=_bearer("no-es-un-token")).status_code == 401


def test_analyses_without_token_is_unauthorized_with_bearer_challenge(jwt_client):
    response = jwt_client.get("/analyses")
    assert (response.status_code, response.headers.get("www-authenticate")) == (401, "Bearer")


def test_invalid_token_is_unauthorized_with_spanish_message(jwt_client):
    response = jwt_client.get("/analyses", headers=_bearer("no-es-un-token"))
    assert response.status_code == 401 and "sesión" in response.json()["detail"]


def test_x_user_id_is_ignored_in_jwt_mode(jwt_client):
    assert post_audio(jwt_client, user="user-a").status_code == 401


def test_full_flow_with_bearer_token(jwt_client):
    headers = _bearer(_token(jwt_client))
    created = _upload(jwt_client, headers)
    analysis_id = created.json()["id"]
    listed = jwt_client.get("/analyses", headers=headers).json()
    fetched = jwt_client.get(f"/analyses/{analysis_id}", headers=headers)
    deleted = jwt_client.delete(f"/analyses/{analysis_id}", headers=headers)
    assert (created.status_code, listed["total"], fetched.status_code, deleted.status_code) == (201, 1, 200, 204)


def test_users_are_isolated_by_token(jwt_client):
    owner, intruder = _bearer(_token(jwt_client)), _bearer(_token(jwt_client))
    analysis_id = _upload(jwt_client, owner).json()["id"]
    assert jwt_client.get(f"/analyses/{analysis_id}", headers=intruder).status_code == 404


def test_intruder_list_is_empty(jwt_client):
    owner, intruder = _bearer(_token(jwt_client)), _bearer(_token(jwt_client))
    _upload(jwt_client, owner)
    assert jwt_client.get("/analyses", headers=intruder).json()["total"] == 0


def test_auth_routes_do_not_exist_in_header_mode(client_factory):
    client, _ = client_factory()
    assert client.post("/auth/token").status_code == 404

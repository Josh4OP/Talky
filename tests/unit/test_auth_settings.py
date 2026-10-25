"""Contrato de la configuración de sesión (T19).

- `AUTH_MODE` es `header` por defecto o `jwt`; otro valor es un error de configuración.
- `JWT_SECRET` no aparece en `repr` y `JWT_TTL_DAYS` vale 30 por defecto.
- En modo `jwt`, el contenedor exige `JWT_SECRET` de al menos 32 caracteres (`ConfigurationError`) y expone
  `token_service`. En modo `header` no crea ningún servicio de tokens.
"""

import dataclasses

import pytest
from fakes import FakeLLM, FakeTranscriber

from src.config.container import build_container
from src.config.settings import Settings
from src.domain.exceptions import ConfigurationError

SECRET = "s" * 32


def test_header_mode_is_the_default():
    settings = Settings.from_env({})
    assert (settings.auth_mode, settings.jwt_secret, settings.jwt_ttl_days) == ("header", "", 30)


def test_env_selects_jwt_mode():
    settings = Settings.from_env({"AUTH_MODE": "JWT", "JWT_SECRET": SECRET, "JWT_TTL_DAYS": "7"})
    assert (settings.auth_mode, settings.jwt_secret, settings.jwt_ttl_days) == ("jwt", SECRET, 7)


def test_unknown_auth_mode_is_rejected():
    with pytest.raises(ValueError, match="AUTH_MODE"):
        Settings.from_env({"AUTH_MODE": "basic"})


def test_secret_is_hidden_from_repr():
    assert SECRET not in repr(Settings.from_env({"JWT_SECRET": SECRET}))


def _container(tmp_path, **values):
    cfg = dataclasses.replace(Settings(), db_path=str(tmp_path / "auth.db"), **values)
    return build_container(cfg, transcriber=FakeTranscriber(), llm_providers=[FakeLLM("a")])


def test_jwt_mode_without_secret_is_a_configuration_error(tmp_path):
    with pytest.raises(ConfigurationError, match="JWT_SECRET"):
        _container(tmp_path, auth_mode="jwt")


def test_jwt_mode_with_short_secret_is_a_configuration_error(tmp_path):
    with pytest.raises(ConfigurationError, match="JWT_SECRET"):
        _container(tmp_path, auth_mode="jwt", jwt_secret="corto")


def test_jwt_mode_builds_a_token_service(tmp_path):
    pytest.importorskip("jwt")
    container = _container(tmp_path, auth_mode="jwt", jwt_secret=SECRET)
    token = container.token_service.issue("talky-abc").access_token
    assert container.token_service.verify(token) == "talky-abc"


def test_header_mode_has_no_token_service(tmp_path):
    assert _container(tmp_path).token_service is None

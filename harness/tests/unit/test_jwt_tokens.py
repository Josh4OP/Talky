"""Contrato de JwtTokenService (T19).

- `issue(subject)` firma un JWT HS256 con `sub`, `iat`, `exp` e `iss="talky"` y devuelve `IssuedToken`
  con el token, el sujeto y `expires_in` en segundos.
- `verify(token)` devuelve el sujeto. Token vencido según el reloj inyectado, firma alterada, otro secreto,
  `alg: none`, emisor distinto o sujeto fuera del patrón de identidad lanzan `InvalidTokenError`.
- El secreto debe tener al menos 32 caracteres y el tiempo de vida debe ser positivo (`ValueError`).
"""

import pytest

pytest.importorskip("jwt")

import jwt  # noqa: E402

from src.domain.exceptions import InvalidTokenError  # noqa: E402
from src.infrastructure.security.jwt_tokens import JwtTokenService  # noqa: E402

SECRET = "s" * 32
OTHER_SECRET = "o" * 32
NOW = 1_800_000_000.0
TTL = 3600


class Clock:
    def __init__(self, now: float = NOW):
        self.now = now

    def __call__(self) -> float:
        return self.now


def make_service(clock=None) -> JwtTokenService:
    return JwtTokenService(SECRET, TTL, clock=clock or Clock())


def test_issue_then_verify_returns_the_subject():
    service = make_service()
    token = service.issue("talky-abc").access_token
    assert service.verify(token) == "talky-abc"


def test_issued_token_reports_subject_and_lifetime():
    issued = make_service().issue("talky-abc")
    assert (issued.subject, issued.expires_in) == ("talky-abc", TTL)


def test_token_carries_the_expected_claims():
    token = make_service().issue("talky-abc").access_token
    claims = jwt.decode(token, SECRET, algorithms=["HS256"], options={"verify_exp": False, "verify_iat": False})
    assert claims == {"sub": "talky-abc", "iat": int(NOW), "exp": int(NOW) + TTL, "iss": "talky"}


def test_token_is_still_valid_just_before_expiry():
    clock = Clock()
    service = make_service(clock)
    token = service.issue("talky-abc").access_token
    clock.now = NOW + TTL - 1
    assert service.verify(token) == "talky-abc"


def test_expired_token_is_rejected():
    clock = Clock()
    service = make_service(clock)
    token = service.issue("talky-abc").access_token
    clock.now = NOW + TTL
    with pytest.raises(InvalidTokenError):
        service.verify(token)


def test_tampered_signature_is_rejected():
    token = make_service().issue("talky-abc").access_token
    head, payload, signature = token.split(".")
    tampered = f"{head}.{payload}.{'A' if signature[0] != 'A' else 'B'}{signature[1:]}"
    with pytest.raises(InvalidTokenError):
        make_service().verify(tampered)


def test_token_signed_with_another_secret_is_rejected():
    token = JwtTokenService(OTHER_SECRET, TTL, clock=Clock()).issue("talky-abc").access_token
    with pytest.raises(InvalidTokenError):
        make_service().verify(token)


def test_unsigned_alg_none_token_is_rejected():
    claims = {"sub": "talky-abc", "iat": int(NOW), "exp": int(NOW) + TTL, "iss": "talky"}
    token = jwt.encode(claims, key=None, algorithm="none")
    with pytest.raises(InvalidTokenError):
        make_service().verify(token)


def test_token_from_another_issuer_is_rejected():
    claims = {"sub": "talky-abc", "iat": int(NOW), "exp": int(NOW) + TTL, "iss": "otro"}
    token = jwt.encode(claims, SECRET, algorithm="HS256")
    with pytest.raises(InvalidTokenError):
        make_service().verify(token)


def test_token_with_invalid_subject_is_rejected():
    claims = {"sub": "../../etc", "iat": int(NOW), "exp": int(NOW) + TTL, "iss": "talky"}
    token = jwt.encode(claims, SECRET, algorithm="HS256")
    with pytest.raises(InvalidTokenError):
        make_service().verify(token)


def test_garbage_is_rejected():
    with pytest.raises(InvalidTokenError):
        make_service().verify("no-es-un-token")


def test_issue_rejects_invalid_subject():
    with pytest.raises(ValueError):
        make_service().issue("con espacios")


def test_short_secret_is_rejected():
    with pytest.raises(ValueError):
        JwtTokenService("corto", TTL)


def test_non_positive_lifetime_is_rejected():
    with pytest.raises(ValueError):
        JwtTokenService(SECRET, 0)


def test_secret_is_not_exposed_in_repr():
    assert SECRET not in repr(make_service())

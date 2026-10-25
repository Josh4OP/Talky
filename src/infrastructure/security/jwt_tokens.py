"""Emisión y verificación de JWT de dispositivo con PyJWT (HS256)."""

import re
import time
from collections.abc import Callable

import jwt

from src.domain.exceptions import InvalidTokenError
from src.domain.interfaces.ports import IssuedToken, TokenService

ALGORITHM = "HS256"
ISSUER = "talky"
MIN_SECRET_CHARS = 32
SUBJECT_PATTERN = re.compile(r"^[A-Za-z0-9_.@-]{1,64}$")
_REQUIRED_CLAIMS = ["sub", "iat", "exp", "iss"]


class JwtTokenService(TokenService):
    """Firma tokens con un secreto del servidor; el reloj inyectado decide el vencimiento."""

    def __init__(self, secret: str, ttl_s: int, clock: Callable[[], float] = time.time):
        if len(secret) < MIN_SECRET_CHARS:
            raise ValueError(f"El secreto de JWT debe tener al menos {MIN_SECRET_CHARS} caracteres.")
        if ttl_s <= 0:
            raise ValueError("La vida del token debe ser mayor que cero.")
        self._secret = secret
        self._ttl_s = ttl_s
        self._clock = clock

    def __repr__(self) -> str:
        return f"JwtTokenService(ttl_s={self._ttl_s})"

    def issue(self, subject: str) -> IssuedToken:
        if not SUBJECT_PATTERN.fullmatch(subject):
            raise ValueError("El sujeto del token no es un identificador válido.")
        now = int(self._clock())
        claims = {"sub": subject, "iat": now, "exp": now + self._ttl_s, "iss": ISSUER}
        return IssuedToken(jwt.encode(claims, self._secret, algorithm=ALGORITHM), subject, self._ttl_s)

    def verify(self, token: str) -> str:
        try:
            # El vencimiento lo decide el reloj inyectado, no el reloj de PyJWT.
            claims = jwt.decode(
                token,
                self._secret,
                algorithms=[ALGORITHM],
                issuer=ISSUER,
                options={"require": _REQUIRED_CLAIMS, "verify_exp": False, "verify_iat": False},
            )
        except jwt.InvalidTokenError as e:
            raise InvalidTokenError(type(e).__name__) from None
        if not isinstance(claims["exp"], int) or claims["exp"] <= self._clock():
            raise InvalidTokenError("ExpiredSignatureError")
        subject = claims["sub"]
        if not isinstance(subject, str) or not SUBJECT_PATTERN.fullmatch(subject):
            raise InvalidTokenError("InvalidSubjectError")
        return subject

"""Rutas de sesión con JWT de dispositivo: emitir, renovar y exigir el token."""

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from src.domain.exceptions import InvalidTokenError
from src.domain.interfaces.ports import IssuedToken, TokenService

logger = logging.getLogger("talky.api")

MISSING_TOKEN = "Falta el token de sesión. Vuelve a abrir la app."
INVALID_TOKEN = "Tu sesión no es válida o venció. Vuelve a abrir la app."

_bearer = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(401, detail, headers={"WWW-Authenticate": "Bearer"})


def bearer_user(tokens: TokenService):
    """Dependencia que devuelve el sujeto del token Bearer o responde 401."""

    def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> str:
        if credentials is None:
            raise _unauthorized(MISSING_TOKEN)
        try:
            return tokens.verify(credentials.credentials)
        except InvalidTokenError as e:
            logger.info("Token rechazado (%s)", e)
            raise _unauthorized(INVALID_TOKEN) from None

    return current_user


def _body(issued: IssuedToken) -> dict:
    return {"access_token": issued.access_token, "token_type": "bearer", "expires_in": issued.expires_in}


def build_auth_router(tokens: TokenService) -> APIRouter:
    router = APIRouter(prefix="/auth")
    current_user = bearer_user(tokens)

    @router.post("/token", status_code=201)
    def create_token() -> dict:
        return _body(tokens.issue(f"talky-{uuid.uuid4().hex}"))

    @router.post("/refresh")
    def refresh_token(user: str = Depends(current_user)) -> dict:
        return _body(tokens.issue(user))

    return router

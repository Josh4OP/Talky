"""Rutas HTTP de análisis e historial (API v1)."""

import dataclasses
import logging
import re
import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, File, Header, HTTPException, Query, Response, UploadFile

from src.domain.exceptions import InvalidAudioError
from src.presentation.routes.auth import bearer_user

logger = logging.getLogger("talky.api")

ALLOWED_EXTENSIONS = (".mp3", ".wav", ".m4a", ".ogg", ".flac", ".webm")
USER_ID_PATTERN = re.compile(r"^[A-Za-z0-9_.@-]{1,64}$")
_CHUNK_BYTES = 1024 * 1024
_MAX_FILENAME = 255

MISSING_USER = "Falta la cabecera X-User-Id."
INVALID_USER = "X-User-Id no es válido: usa de 1 a 64 letras, números o los signos . _ @ -"
UNSUPPORTED_FORMAT = f"Formato de audio no compatible. Usa uno de: {', '.join(ALLOWED_EXTENSIONS)}"
NOT_FOUND = "Análisis no encontrado."
UNREADABLE_AUDIO = "No se pudo procesar el audio. Verifica que sea una grabación válida."
SERVICES_DOWN = (
    "No fue posible completar el análisis: los servicios de transcripción o de análisis no respondieron. "
    "Intenta de nuevo en unos minutos."
)


def user_id(x_user_id: str | None = Header(default=None, alias="X-User-Id")) -> str:
    if x_user_id is None:
        raise HTTPException(401, MISSING_USER)
    if not USER_ID_PATTERN.fullmatch(x_user_id):
        raise HTTPException(400, INVALID_USER)
    return x_user_id


def _identity(container):
    """En modo jwt la identidad sale del token; en modo header, de X-User-Id."""
    if container.settings.auth_mode == "jwt":
        return bearer_user(container.token_service)
    return user_id


def _too_large(max_mb: int) -> HTTPException:
    return HTTPException(413, f"El archivo supera el límite de {max_mb} MB.")


def _save_upload(upload: UploadFile, suffix: str, max_bytes: int, max_mb: int) -> str:
    """Copia la subida a un temporal por bloques y corta en cuanto pasa del límite; devuelve la ruta."""
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        path = tmp.name
        written = 0
        try:
            while chunk := upload.file.read(_CHUNK_BYTES):
                written += len(chunk)
                if written > max_bytes:
                    raise _too_large(max_mb)
                tmp.write(chunk)
        except BaseException:
            tmp.close()
            Path(path).unlink(missing_ok=True)
            raise
    return path


def _public(stored) -> dict:
    return {"id": stored.id, "creado_en": stored.created_at, **stored.result}


def build_router(container) -> APIRouter:
    router = APIRouter()
    use_case = container.use_case
    repository = container.repository
    max_mb = container.settings.max_upload_mb
    identity = _identity(container)

    @router.post("/analyses", status_code=201)
    def create_analysis(file: UploadFile = File(...), user: str = Depends(identity)) -> dict:
        filename = Path(file.filename or "audio").name[:_MAX_FILENAME]
        suffix = Path(filename).suffix.lower()
        if suffix not in ALLOWED_EXTENSIONS:
            raise HTTPException(400, UNSUPPORTED_FORMAT)

        path = None
        try:
            path = _save_upload(file, suffix, max_mb * 1024 * 1024, max_mb)
            result = use_case.execute(path)
        except InvalidAudioError as e:
            raise HTTPException(422, str(e))
        except ValueError as e:
            logger.warning("Audio no procesable (%s)", type(e).__name__)
            raise HTTPException(422, UNREADABLE_AUDIO)
        except RuntimeError as e:
            logger.warning("Proveedores no disponibles (%s)", type(e).__name__)
            raise HTTPException(503, SERVICES_DOWN)
        finally:
            if path is not None:
                Path(path).unlink(missing_ok=True)

        analysis_id = repository.save(user, filename, result)
        return _public(repository.get(user, analysis_id))

    @router.get("/analyses")
    def list_analyses(
        user: str = Depends(identity),
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0),
    ) -> dict:
        items = [dataclasses.asdict(s) for s in repository.list(user, limit=limit, offset=offset)]
        return {"items": items, "total": repository.count(user), "limit": limit, "offset": offset}

    @router.get("/analyses/{analysis_id}")
    def get_analysis(analysis_id: str, user: str = Depends(identity)) -> dict:
        stored = repository.get(user, analysis_id)
        if stored is None:
            raise HTTPException(404, NOT_FOUND)
        return _public(stored)

    @router.delete("/analyses/{analysis_id}", status_code=204)
    def delete_analysis(analysis_id: str, user: str = Depends(identity)) -> Response:
        if not repository.delete(user, analysis_id):
            raise HTTPException(404, NOT_FOUND)
        return Response(status_code=204)

    return router

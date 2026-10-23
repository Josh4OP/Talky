import os
import shutil
import tempfile

from fastapi import APIRouter, File, HTTPException, UploadFile

ALLOWED = {".mp3", ".wav", ".m4a", ".ogg", ".flac", ".webm"}
MAX_MB = 100


def build_router(use_case) -> APIRouter:
    router = APIRouter()

    @router.post("/analyses")
    def create_analysis(file: UploadFile = File(...)):
        ext = os.path.splitext(file.filename or "")[1].lower()
        if ext not in ALLOWED:
            raise HTTPException(400, f"Formato no compatible. Formatos válidos: {', '.join(sorted(ALLOWED))}")

        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
                tmp_path = tmp.name
                shutil.copyfileobj(file.file, tmp)

            if os.path.getsize(tmp_path) > MAX_MB * 1024 * 1024:
                raise HTTPException(413, f"El archivo supera {MAX_MB} MB")

            return use_case.execute(tmp_path)
        except HTTPException:
            raise
        except ValueError as e:
            raise HTTPException(422, str(e))
        except RuntimeError as e:
            raise HTTPException(503, str(e))
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)

    return router

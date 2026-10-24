"""Aplicación FastAPI de TALKY: recibe el contenedor ya armado."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.presentation.routes.analysis import build_router


def create_app(container) -> FastAPI:
    app = FastAPI(title="TALKY", description="Retroalimentación sobre exposiciones orales a partir de audio.")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(container.settings.cors_origins),
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(build_router(container))
    use_case = container.use_case

    @app.get("/health")
    def health() -> dict:
        return {
            "status": "ok",
            "features": {
                "event_classifier": use_case.event_classifier is not None,
                "text_embeddings": use_case.embedder is not None,
                "verifier": use_case.verify,
            },
            "modelos": [p.name for p in use_case.ensemble.providers],
            "advertencias": list(container.warnings),
        }

    return app

import logging
import os

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.application.services.ensemble import EnsembleAnalyzer
from src.application.use_cases.analyze_presentation import AnalyzePresentation
from src.infrastructure.external.openai_compatible_llm import OpenAICompatibleLLM
from src.infrastructure.external.whisper_transcriber import WhisperTranscriber
from src.presentation.routes.analysis import build_router

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("talky")

PROVIDER_SPECS = {
    "groq": ("https://api.groq.com/openai/v1", "GROQ_API_KEY", "GROQ_MODEL"),
    "gemini": ("https://generativelanguage.googleapis.com/v1beta/openai/",
               "GEMINI_API_KEY", "GEMINI_MODEL"),
    "ollama": ("http://localhost:11434/v1", None, "OLLAMA_MODEL"),
}


def build_providers():
    providers = {}
    for name, (url, key_env, model_env) in PROVIDER_SPECS.items():
        model = os.getenv(model_env, "").strip()
        key = os.getenv(key_env, "").strip() if key_env else "ollama"
        if model and key:
            providers[name] = OpenAICompatibleLLM(name, url, key, model)
        else:
            log.info("Proveedor '%s' desactivado", name)
    return providers


providers = build_providers()
if not providers:
    raise SystemExit("No hay ningún LLM configurado. Revisa tu archivo .env")

judge_name = os.getenv("JUDGE_PROVIDER", "gemini").strip()
judge = providers.get(judge_name) or next(iter(providers.values()))
min_ok = int(os.getenv("MIN_MODELS_OK", "1"))
log.info("LLMs activos: %s | juez: %s | mínimo para responder: %d",
         list(providers), judge.name, min_ok)

ensemble = EnsembleAnalyzer(list(providers.values()), judge=judge, min_ok=min_ok)
transcriber = WhisperTranscriber(os.getenv("WHISPER_MODEL", "small"))
use_case = AnalyzePresentation(
    transcriber, ensemble, max_chars=int(os.getenv("MAX_TRANSCRIPT_CHARS", "12000")))

app = FastAPI(title="TALKY")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(build_router(use_case))


@app.get("/health")
def health():
    return {"status": "ok", "llms": list(providers), "juez": judge.name}
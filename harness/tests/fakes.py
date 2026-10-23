"""Dobles de prueba compartidos por todos los tests de aceptación.

No dependen de red, claves ni modelos pesados. Importan solo contratos de
`src.domain` (puertos y entidades), de modo que sirven tanto para pruebas
unitarias como para las de integración con la API.
"""

from __future__ import annotations

import io
import json
import math
import struct
import wave

from src.domain.interfaces.ports import LLMProvider, Segment, Transcriber, Transcription, Word

# --------------------------------------------------------------------------- #
# Datos de ejemplo
# --------------------------------------------------------------------------- #
SAMPLE_TEXT = (
    "Eh, buenos días a todos. Hoy voy a hablar sobre el cambio climático. "
    "Mmm, o sea, es un problema muy importante para todos nosotros. "
    "El cambio climático afecta a todos los países del mundo. "
    "Entonces, vamos a ver las causas principales y las posibles soluciones. "
    "Para terminar, quiero agradecerles por su atención."
)

#: Cita que SÍ existe en SAMPLE_TEXT.
VALID_QUOTE = "el cambio climático afecta a todos los países del mundo"
#: Cita inventada: NO existe en SAMPLE_TEXT.
INVENTED_QUOTE = "el orador menciona el protocolo de Kioto con todo detalle"


def sample_transcription(word_s: float = 0.35, gap_s: float = 0.05, sentence_pause_s: float = 1.6) -> Transcription:
    """Transcripción determinista con palabras, segmentos y pausas largas entre oraciones."""
    words: list[Word] = []
    segments: list[Segment] = []
    t = 0.0
    seg_start = 0.0
    seg_tokens: list[str] = []
    for token in SAMPLE_TEXT.split():
        words.append(Word(start=round(t, 3), end=round(t + word_s, 3), text=token))
        seg_tokens.append(token)
        t += word_s + gap_s
        if token.endswith("."):
            segments.append(Segment(start=round(seg_start, 3), end=round(t - gap_s, 3), text=" ".join(seg_tokens)))
            seg_tokens = []
            t += sentence_pause_s
            seg_start = t
    if seg_tokens:
        segments.append(Segment(start=round(seg_start, 3), end=round(t, 3), text=" ".join(seg_tokens)))
    return Transcription(text=SAMPLE_TEXT, segments=segments, duration=round(t + 0.5, 3), words=words)


def make_wav_bytes(seconds: float = 1.0, sr: int = 16000, freq: float = 220.0, amp: float = 0.3) -> bytes:
    """Genera un WAV mono 16-bit con una senoidal (para probar subidas de archivo)."""
    n = int(seconds * sr)
    frames = b"".join(struct.pack("<h", int(amp * 32767 * math.sin(2 * math.pi * freq * i / sr))) for i in range(n))
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(frames)
    return buf.getvalue()


def post_audio(client, *, user="user-a", filename="charla.wav", content=None, content_type="audio/wav"):
    """Atajo para subir un audio a POST /analyses con un TestClient de FastAPI."""
    headers = {"X-User-Id": user} if user is not None else {}
    data = content if content is not None else make_wav_bytes(1.0)
    return client.post("/analyses", files={"file": (filename, data, content_type)}, headers=headers)


# --------------------------------------------------------------------------- #
# Transcriptor
# --------------------------------------------------------------------------- #
class FakeTranscriber(Transcriber):
    def __init__(self, transcription: Transcription | None = None, error: Exception | None = None):
        self.transcription = transcription or sample_transcription()
        self.error = error
        self.paths: list[str] = []

    def transcribe(self, audio_path: str) -> Transcription:
        self.paths.append(audio_path)
        if self.error:
            raise self.error
        return self.transcription


# --------------------------------------------------------------------------- #
# LLM
# --------------------------------------------------------------------------- #
def analysis_payload(evidencias: list[dict] | None = None) -> dict:
    return {
        "organizacion": {"puntaje": 7, "comentario": "Estructura clara"},
        "claridad": {"puntaje": 6, "comentario": "Se entiende"},
        "repeticion": {"puntaje": 5, "comentario": "Repite 'todos'", "palabras_repetidas": ["todos"]},
        "fortalezas": ["Buen cierre"],
        "aspectos_por_mejorar": ["Reducir muletillas"],
        "recomendaciones": ["Practicar pausas"],
        "evidencias": evidencias
        if evidencias is not None
        else [
            {"afirmacion": "Presenta el tema con claridad", "cita": VALID_QUOTE},
            {"afirmacion": "Cita un tratado internacional", "cita": INVENTED_QUOTE},
        ],
    }


def synthesis_payload(label: str = "x") -> dict:
    return {
        "resumen": f"resumen-{label}",
        "fortalezas": ["Buen cierre"],
        "aspectos_por_mejorar": ["Reducir muletillas"],
        "recomendaciones": ["Practicar pausas"],
    }


class FakeLLM(LLMProvider):
    """Proveedor de LLM falso.

    Distingue la llamada del juez porque su prompt de sistema empieza con
    "Eres un editor" (contrato del prompt del juez, ver tests/unit/test_prompts.py).
    """

    def __init__(
        self,
        name: str,
        *,
        analysis: dict | None = None,
        fail_analysis: Exception | None = None,
        fail_synthesis: Exception | None = None,
    ):
        self.name = name
        self.analysis = analysis
        self.fail_analysis = fail_analysis
        self.fail_synthesis = fail_synthesis
        self.calls: list[str] = []

    def complete_json(self, system: str, user: str) -> str:
        is_judge = "eres un editor" in system.lower()
        self.calls.append("judge" if is_judge else "analysis")
        error = self.fail_synthesis if is_judge else self.fail_analysis
        if error:
            raise error
        payload = synthesis_payload(self.name) if is_judge else (self.analysis or analysis_payload())
        return json.dumps(payload, ensure_ascii=False)


# --------------------------------------------------------------------------- #
# Embeddings y eventos acústicos
# --------------------------------------------------------------------------- #
class ScriptedEmbedder:
    """Devuelve vectores predefinidos en orden. Con cycle=True los repite."""

    def __init__(self, vectors: list[list[float]], cycle: bool = False, error: Exception | None = None):
        self.vectors = vectors
        self.cycle = cycle
        self.error = error
        self.calls: list[int] = []

    def embed(self, texts: list[str]) -> list[list[float]]:
        self.calls.append(len(texts))
        if self.error:
            raise self.error
        if self.cycle:
            return [self.vectors[i % len(self.vectors)] for i in range(len(texts))]
        if len(texts) > len(self.vectors):
            raise AssertionError(f"ScriptedEmbedder: se pidieron {len(texts)} vectores y hay {len(self.vectors)}")
        return self.vectors[: len(texts)]


class FakeEventClassifier:
    def __init__(self, events: list | None = None, error: Exception | None = None):
        self.events = events or []
        self.error = error
        self.paths: list[str] = []

    def classify(self, audio_path: str) -> list:
        self.paths.append(audio_path)
        if self.error:
            raise self.error
        return list(self.events)

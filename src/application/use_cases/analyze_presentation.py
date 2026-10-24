"""Caso de uso: analizar una exposición oral grabada de punta a punta."""

import logging

from src.application.prompts import ANALYSIS_SYSTEM, build_user_message
from src.application.services.coherence import CoherenceReport, coherence_report
from src.application.services.ensemble import EnsembleAnalyzer
from src.application.services.event_fusion import FusionResult, fuse_fillers
from src.application.services.filler_detector import detect_fillers, fillers_per_minute
from src.application.services.metrics import pause_stats_from_words, rhythm_profile, words_per_minute
from src.application.services.transcript import select_window
from src.domain.exceptions import InvalidAudioError
from src.domain.interfaces.ports import EventClassifier, TextEmbedder, Transcriber, Transcription

logger = logging.getLogger("talky.analysis")

NO_SPEECH = "No se detectó voz en el audio"
COHERENCE_FAILED = "No se pudo calcular la coherencia temática; el resto del análisis está completo."
EVENTS_FAILED = (
    "No se pudo analizar los eventos acústicos (muletillas vocales y tatareos); el resto del análisis está completo."
)
# Sin marcas por palabra, las pausas se miden entre segmentos, que separan frases y no palabras.
_SEGMENT_PAUSE_S = 1.5


def _pauses(tr: Transcription) -> dict:
    if tr.words:
        return pause_stats_from_words(tr.words, tr.duration)
    return pause_stats_from_words(tr.segments, tr.duration, min_gap=_SEGMENT_PAUSE_S)


def _events_dict(fusion: FusionResult) -> dict:
    return {
        "muletillas": [hit.to_dict() for hit in fusion.fillers],
        "tarareos": [
            {"start": round(h.start, 3), "end": round(h.end, 3), "confidence": round(h.confidence, 3)}
            for h in fusion.hums
        ],
    }


def _objective_line(
    tr: Transcription, ppm: float, pausas: dict, fillers: dict, per_minute: float, coherence, fusion
) -> str:
    listed = ", ".join(f"{k} {n}" for k, n in fillers.items()) or "ninguna"
    parts = [
        f"Duración: {tr.duration:.0f} s",
        f"Ritmo: {ppm} palabras/min",
        f"Pausas largas: {pausas['pausas_largas']} (máxima {pausas['pausa_maxima_s']} s)",
        f"Muletillas: {listed} ({per_minute} por minuto)",
    ]
    if coherence is not None:
        parts.append(
            f"Coherencia: {len(coherence.topic_jumps)} saltos de tema, {len(coherence.repeated_pairs)} ideas repetidas"
        )
    if fusion is not None:
        parts.append(f"Audio: {len(fusion.fillers)} muletillas vocales, {len(fusion.hums)} tatareos")
    return "Datos objetivos medidos por el sistema: " + " | ".join(parts)


class AnalyzePresentation:
    """Transcribe, mide, consulta al ensamble de LLM y arma el resultado del contrato HTTP."""

    def __init__(
        self,
        transcriber: Transcriber,
        ensemble: EnsembleAnalyzer,
        *,
        max_chars: int = 12000,
        embedder: TextEmbedder | None = None,
        event_classifier: EventClassifier | None = None,
        verify: bool = True,
    ):
        self.transcriber = transcriber
        self.ensemble = ensemble
        self.max_chars = max_chars
        self.embedder = embedder
        self.event_classifier = event_classifier
        self.verify = verify

    def _coherence(self, text: str, warnings: list[str]) -> CoherenceReport | None:
        if self.embedder is None:
            return None
        try:
            return coherence_report(text, self.embedder)
        except Exception as e:  # noqa: BLE001
            logger.warning("Etapa de coherencia falló (%s)", type(e).__name__)
            warnings.append(COHERENCE_FAILED)
            return None

    def _acoustic_events(self, audio_path: str, tr: Transcription, warnings: list[str]) -> FusionResult | None:
        if self.event_classifier is None:
            return None
        try:
            return fuse_fillers(tr.words, self.event_classifier.classify(audio_path))
        except Exception as e:  # noqa: BLE001
            logger.warning("Etapa de eventos acústicos falló (%s)", type(e).__name__)
            warnings.append(EVENTS_FAILED)
            return None

    def execute(self, audio_path: str) -> dict:
        tr = self.transcriber.transcribe(audio_path)
        if not tr.text.strip():
            raise InvalidAudioError(NO_SPEECH)
        warnings = list(tr.warnings)

        fillers = detect_fillers(tr.text)
        per_minute = fillers_per_minute(fillers, tr.duration)
        ppm = words_per_minute(tr.text, tr.duration)
        pausas = _pauses(tr)
        coherence = self._coherence(tr.text, warnings)
        fusion = self._acoustic_events(audio_path, tr, warnings)

        window, truncated = select_window(tr.text, self.max_chars)
        objective = _objective_line(tr, ppm, pausas, fillers, per_minute, coherence, fusion)
        analysis = self.ensemble.analyze(
            ANALYSIS_SYSTEM,
            build_user_message(objective, window, truncated),
            objective_data=objective,
            transcript=tr.text,
            verify=self.verify,
        )
        return {
            "duracion_s": round(tr.duration, 1),
            "ppm": ppm,
            "ritmo": rhythm_profile(tr.words, tr.duration) if tr.words else [],
            "pausas": pausas,
            "muletillas": fillers,
            "muletillas_por_minuto": per_minute,
            "transcripcion_recortada": truncated,
            "coherencia": coherence.to_dict() if coherence is not None else None,
            "eventos_acusticos": _events_dict(fusion) if fusion is not None else None,
            "advertencias": warnings,
            **analysis,
        }

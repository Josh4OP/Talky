"""Transcripción local con faster-whisper (respaldo cuando Groq no está disponible)."""

from src.domain.interfaces.ports import Segment, Transcriber, Transcription, Word
from src.infrastructure.audio import load_audio
from src.infrastructure.external.groq_transcriber import DEFAULT_PROMPT


class WhisperTranscriber(Transcriber):
    """Carga el modelo una sola vez al construirse; faster_whisper se importa aquí y no al importar el módulo."""

    def __init__(self, model_size: str = "small", language: str = "es"):
        from faster_whisper import WhisperModel

        self.language = language
        self.model = WhisperModel(model_size, device="cpu", compute_type="int8")

    def transcribe(self, audio_path: str) -> Transcription:
        audio = load_audio(audio_path)
        raw_segments, info = self.model.transcribe(
            audio,
            language=self.language,
            initial_prompt=DEFAULT_PROMPT,
            vad_filter=True,
            word_timestamps=True,
        )
        segments: list[Segment] = []
        words: list[Word] = []
        for s in raw_segments:
            segments.append(Segment(s.start, s.end, s.text.strip()))
            words.extend(Word(w.start, w.end, w.word.strip()) for w in s.words or [])
        text = " ".join(s.text for s in segments).strip()
        return Transcription(text, segments, info.duration, words=words)

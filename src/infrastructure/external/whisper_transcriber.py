import av
import numpy as np
from faster_whisper import WhisperModel

from src.domain.interfaces.ports import Segment, Transcriber, Transcription

_PROMPT = "Eh, bueno, o sea, mmm, este... digamos que, como que, ¿no? Entonces, eh..."
_SAMPLE_RATE = 16000


def _load_audio(path: str) -> np.ndarray:
    """Lee cualquier audio y lo devuelve mono, 16 kHz, float32 (lo que Whisper espera)."""
    container = av.open(path)
    resampler = av.AudioResampler(format="s16", layout="mono", rate=_SAMPLE_RATE)
    chunks = []
    try:
        for frame in container.decode(audio=0):
            for out in resampler.resample(frame):
                chunks.append(out.to_ndarray().reshape(-1))
        for out in resampler.resample(None):  # vaciar lo que quede en el buffer
            chunks.append(out.to_ndarray().reshape(-1))
    finally:
        container.close()
    if not chunks:
        raise ValueError("No se pudo leer audio del archivo")
    return np.concatenate(chunks).astype(np.float32) / 32768.0


class WhisperTranscriber(Transcriber):
    def __init__(self, model_size: str = "small", language: str = "es"):
        self.language = language
        self.model = WhisperModel(model_size, device="cpu", compute_type="int8")

    def transcribe(self, audio_path: str) -> Transcription:
        audio = _load_audio(audio_path)
        segs, info = self.model.transcribe(
            audio,
            language=self.language,
            initial_prompt=_PROMPT,
            vad_filter=True,
        )
        segments = [Segment(s.start, s.end, s.text.strip()) for s in segs]
        text = " ".join(s.text for s in segments).strip()
        return Transcription(text, segments, info.duration)
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class Segment:
    start: float
    end: float
    text: str


@dataclass
class Transcription:
    text: str
    segments: list[Segment]
    duration: float


class Transcriber(ABC):
    @abstractmethod
    def transcribe(self, audio_path: str) -> Transcription: ...


class LLMProvider(ABC):
    name: str

    @abstractmethod
    def complete_json(self, system: str, user: str) -> str: ...

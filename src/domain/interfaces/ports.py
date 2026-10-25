"""Puertos del dominio y los datos que cruzan entre capas."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class Segment:
    start: float
    end: float
    text: str


@dataclass
class Word:
    start: float
    end: float
    text: str


@dataclass
class Transcription:
    text: str
    segments: list[Segment]
    duration: float
    words: list[Word] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


@dataclass
class StoredAnalysis:
    id: str
    user_id: str
    filename: str
    created_at: str
    result: dict


@dataclass
class AnalysisSummary:
    id: str
    filename: str
    created_at: str
    duracion_s: float | None
    ppm: float | None
    total_muletillas: int


@dataclass(frozen=True)
class IssuedToken:
    access_token: str = field(repr=False)
    subject: str
    expires_in: int


class Transcriber(ABC):
    @abstractmethod
    def transcribe(self, audio_path: str) -> Transcription: ...


class LLMProvider(ABC):
    name: str

    @abstractmethod
    def complete_json(self, system: str, user: str) -> str: ...


class TextEmbedder(ABC):
    @abstractmethod
    def embed(self, texts: list[str]) -> list[list[float]]: ...


class EventClassifier(ABC):
    @abstractmethod
    def classify(self, audio_path: str) -> list: ...


class AnalysisRepository(ABC):
    @abstractmethod
    def save(self, user_id: str, filename: str, result: dict) -> str: ...

    @abstractmethod
    def get(self, user_id: str, analysis_id: str) -> StoredAnalysis | None: ...

    @abstractmethod
    def list(self, user_id: str, limit: int = 50, offset: int = 0) -> list[AnalysisSummary]: ...

    @abstractmethod
    def count(self, user_id: str) -> int: ...

    @abstractmethod
    def delete(self, user_id: str, analysis_id: str) -> bool: ...


class TokenService(ABC):
    @abstractmethod
    def issue(self, subject: str) -> IssuedToken: ...

    @abstractmethod
    def verify(self, token: str) -> str: ...

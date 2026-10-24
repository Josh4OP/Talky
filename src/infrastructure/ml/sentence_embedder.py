"""Embeddings de texto con sentence-transformers (MiniLM multilingüe, CPU)."""

import threading
from collections.abc import Callable

from src.domain.interfaces.ports import TextEmbedder

DEFAULT_MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


def _load_sentence_transformer(model_name: str):
    from sentence_transformers import SentenceTransformer

    return SentenceTransformer(model_name, device="cpu")


class SentenceTransformerEmbedder(TextEmbedder):
    """Carga el modelo en el primer uso (una sola vez, también con hilos) y devuelve vectores normalizados."""

    def __init__(self, model_name: str = DEFAULT_MODEL, *, loader: Callable[[str], object] | None = None):
        self.model_name = model_name
        self._loader = loader or _load_sentence_transformer
        self._model = None
        self._lock = threading.Lock()

    def _get_model(self):
        if self._model is None:
            with self._lock:
                if self._model is None:
                    self._model = self._loader(self.model_name)
        return self._model

    def embed(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []
        vectors = self._get_model().encode(list(texts), normalize_embeddings=True, convert_to_numpy=True)
        return [[float(x) for x in vector] for vector in vectors]

"""T09 - Reglas de coherencia y del embedder que no cubren las pruebas de aceptación.

Contrato: harness/context/10-module-contracts.md (coherence.py, sentence_embedder.py) y context/04-ml-design.md §3
  - Saltos: similitud adyacente estrictamente menor al umbral; repetidas: estrictamente mayor.
  - min_gap es configurable; to_dict redondea a 3 decimales.
  - Vectores de distinta dimensión o ventanas de tamaño no positivo son errores de programación.
  - SentenceTransformerEmbedder: no carga nada al construirse ni con una lista vacía, carga una sola vez
    (también con hilos), pide vectores normalizados y devuelve listas de floats.
"""

import threading

import pytest
from fakes import ScriptedEmbedder

from src.application.services.coherence import coherence_report, cosine, make_windows
from src.infrastructure.ml.sentence_embedder import DEFAULT_MODEL, SentenceTransformerEmbedder

TWELVE = " ".join(f"Oración número {i}." for i in range(12))


def test_similarity_equal_to_the_thresholds_is_neither_a_jump_nor_a_repeat():
    emb = ScriptedEmbedder([[1, 0], [0.6, 0.8], [1, 0], [0.6, 0.8]])
    r = coherence_report(TWELVE, emb, topic_jump_threshold=0.6, repeat_threshold=1.0)
    assert (r.topic_jumps, r.repeated_pairs) == ([], [])


def test_min_gap_is_configurable():
    emb = ScriptedEmbedder([[1, 0], [1, 0], [0, 1], [0, 1]])
    r = coherence_report(TWELVE, emb, min_gap=1)
    assert [(a, b) for a, b, _ in r.repeated_pairs] == [(0, 1), (2, 3)]


def test_to_dict_rounds_to_three_decimals():
    emb = ScriptedEmbedder([[1, 0], [0.8, 0.6], [0.6, 0.8], [0, 1]])
    assert coherence_report(TWELVE, emb).to_dict()["mean_adjacent_similarity"] == 0.853


def test_embedder_errors_propagate_so_the_use_case_can_degrade():
    with pytest.raises(RuntimeError):
        coherence_report(TWELVE, ScriptedEmbedder([], error=RuntimeError("modelo no disponible")))


def test_mismatched_dimensions_and_bad_window_size_are_errors():
    with pytest.raises(ValueError):
        cosine([1, 0], [1, 0, 0])
    with pytest.raises(ValueError):
        make_windows(["a."], 0)


class _FakeModel:
    def __init__(self):
        self.calls = []

    def encode(self, texts, **kwargs):
        self.calls.append(kwargs)
        return [[0.6, 0.8] for _ in texts]


def test_embedder_loads_lazily_once_and_requests_normalized_vectors():
    loads = []
    model = _FakeModel()

    def loader(name):
        loads.append(name)
        return model

    embedder = SentenceTransformerEmbedder(loader=loader)
    assert loads == []
    assert embedder.embed([]) == [] and loads == []
    assert embedder.embed(["hola", "buenos días"]) == [[0.6, 0.8], [0.6, 0.8]]
    embedder.embed(["otra"])
    assert loads == [DEFAULT_MODEL]
    assert model.calls[0]["normalize_embeddings"] is True


def test_embedder_loads_once_with_concurrent_threads():
    loads = []
    barrier = threading.Barrier(8)
    embedder = SentenceTransformerEmbedder(loader=lambda name: loads.append(name) or _FakeModel())

    def work():
        barrier.wait()
        embedder.embed(["hola"])

    threads = [threading.Thread(target=work) for _ in range(8)]
    [t.start() for t in threads]
    [t.join() for t in threads]
    assert len(loads) == 1


def test_embedder_returns_plain_floats():
    np = pytest.importorskip("numpy")

    class NumpyModel:
        def encode(self, texts, **kwargs):
            return np.ones((len(texts), 3), dtype=np.float32)

    vectors = SentenceTransformerEmbedder(loader=lambda name: NumpyModel()).embed(["a"])
    assert vectors == [[1.0, 1.0, 1.0]] and type(vectors[0][0]) is float

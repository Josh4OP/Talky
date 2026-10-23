"""T03 - Detector de muletillas con contexto (RF-04).

Contrato: src/application/services/filler_detector.py
  detect_fillers(text: str) -> dict[str, int]      # ordenado de mayor a menor
  fillers_per_minute(counts: dict[str, int], duration_s: float) -> float
"""

import pytest

from src.application.services.filler_detector import detect_fillers, fillers_per_minute


class TestAlwaysFillers:
    def test_vocal_fillers_are_normalized_to_a_canonical_key(self):
        assert detect_fillers("Eh, hola. Ehhh, mmmm...") == {"eh": 2, "mmm": 1}

    def test_hmm_and_ehm_variants(self):
        assert detect_fillers("Hmm, no sé. Entonces ehm tema") == {"mmm": 1, "eh": 1}

    def test_discourse_markers_that_are_always_fillers(self):
        text = "O sea, digamos que, como que no sé, en plan nada"
        assert detect_fillers(text) == {"o sea": 1, "digamos": 1, "como que": 1, "en plan": 1}

    def test_tag_questions(self):
        assert detect_fillers("Eso es así, ¿no? Ajá, ¿verdad?") == {"¿no?": 1, "¿verdad?": 1}

    def test_case_insensitive(self):
        assert detect_fillers("EH, O SEA,") == {"eh": 1, "o sea": 1}


class TestContextualFillers:
    @pytest.mark.parametrize(
        "text",
        [
            "Este modelo es mejor que el anterior",
            "Tipo de dato entero",
            "Entonces el resultado es bueno",
            "Pues bien, empecemos",
            "El examen estuvo bueno",
        ],
    )
    def test_legitimate_uses_are_not_counted(self, text):
        assert detect_fillers(text) == {}

    @pytest.mark.parametrize(
        "text,key",
        [
            ("Este, el modelo funciona", "este"),
            ("Entonces, el resultado", "entonces"),
            ("Bueno... empecemos", "bueno"),
            ("Pues, no sé", "pues"),
            ("Tipo, no sé qué decir", "tipo"),
            ("Básicamente, es eso", "básicamente"),
        ],
    )
    def test_counted_when_followed_by_a_pause(self, text, key):
        assert detect_fillers(text) == {key: 1}

    def test_counted_when_it_is_the_whole_sentence(self):
        assert detect_fillers("Bueno. Empecemos.") == {"bueno": 1}

    def test_la_verdad_is_not_double_counted(self):
        assert detect_fillers("La verdad, no sé") == {"la verdad": 1}

    def test_la_verdad_as_a_noun_is_ignored(self):
        assert detect_fillers("Esa es la verdad de los hechos") == {}


class TestRobustness:
    def test_no_substring_matches(self):
        assert detect_fillers("La prehistoria es larga y la mesa es grande") == {}

    def test_empty_text(self):
        assert detect_fillers("") == {}

    def test_sorted_from_most_to_least_frequent(self):
        counts = detect_fillers("O sea, eh, eh, eh, mmm,")
        assert list(counts.items())[0] == ("eh", 3)
        assert list(counts.values()) == sorted(counts.values(), reverse=True)


class TestFillersPerMinute:
    def test_rate(self):
        assert fillers_per_minute({"eh": 3, "o sea": 3}, 120) == 3.0

    def test_zero_duration(self):
        assert fillers_per_minute({"eh": 3}, 0) == 0.0

    def test_empty_counts(self):
        assert fillers_per_minute({}, 60) == 0.0

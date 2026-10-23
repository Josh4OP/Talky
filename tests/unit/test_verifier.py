"""T08 - Verificador de evidencias (patrón evaluator, sin LLM).

Contrato: src/application/services/verifier.py
  normalize(text) -> str
  quote_in_transcript(quote, transcript, min_ratio=0.85) -> bool
  verify_evidences(evidencias, transcript) -> list[Evidencia]      # copias, no muta
  drop_unverified(evidencias) -> list[Evidencia]
  verification_rate(evidencias) -> float | None
Entidad: src/domain/entities/analysis.py -> Evidencia(afirmacion, cita="", verificada=None)
"""

from fakes import INVENTED_QUOTE, SAMPLE_TEXT, VALID_QUOTE
from src.application.services.verifier import (
    drop_unverified,
    normalize,
    quote_in_transcript,
    verification_rate,
    verify_evidences,
)

from src.domain.entities.analysis import Evidencia


class TestNormalize:
    def test_lowercase_accents_punctuation_and_spaces(self):
        assert normalize("  Está   AQUÍ, ¿sí? ") == "esta aqui si"

    def test_empty(self):
        assert normalize("") == ""


class TestQuoteInTranscript:
    def test_exact_quote(self):
        assert quote_in_transcript(VALID_QUOTE, SAMPLE_TEXT) is True

    def test_case_punctuation_and_accents_do_not_matter(self):
        assert quote_in_transcript("EL CAMBIO CLIMATICO, afecta a todos los paises del mundo!", SAMPLE_TEXT) is True

    def test_small_asr_variation_is_tolerated(self):
        assert quote_in_transcript("el cambio climático afectan a todos los países del mundo", SAMPLE_TEXT) is True

    def test_invented_quote_is_rejected(self):
        assert quote_in_transcript(INVENTED_QUOTE, SAMPLE_TEXT) is False

    def test_paraphrase_is_rejected(self):
        assert quote_in_transcript("el calentamiento global perjudica a las naciones", SAMPLE_TEXT) is False

    def test_empty_and_too_short_quotes_are_rejected(self):
        assert quote_in_transcript("", SAMPLE_TEXT) is False
        assert quote_in_transcript("todos", SAMPLE_TEXT) is False  # menos de 3 palabras no prueba nada

    def test_empty_transcript(self):
        assert quote_in_transcript(VALID_QUOTE, "") is False


class TestVerifyEvidences:
    def _items(self):
        return [
            Evidencia(afirmacion="Presenta el tema", cita=VALID_QUOTE),
            Evidencia(afirmacion="Cita un tratado", cita=INVENTED_QUOTE),
            Evidencia(afirmacion="Sin cita", cita=""),
        ]

    def test_marks_each_item_and_does_not_mutate_the_input(self):
        original = self._items()
        result = verify_evidences(original, SAMPLE_TEXT)
        assert [e.verificada for e in result] == [True, False, False]
        assert [e.verificada for e in original] == [None, None, None]

    def test_drop_unverified(self):
        kept = drop_unverified(verify_evidences(self._items(), SAMPLE_TEXT))
        assert [e.afirmacion for e in kept] == ["Presenta el tema"]

    def test_drop_unverified_ignores_items_never_verified(self):
        assert drop_unverified(self._items()) == []

    def test_verification_rate(self):
        assert verification_rate(verify_evidences(self._items(), SAMPLE_TEXT)) == 1 / 3
        assert verification_rate([]) is None

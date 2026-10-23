"""T08 - Prompts versionados en código (contrato verificable).

Contrato: src/application/prompts.py
  ANALYSIS_SYSTEM: str        # prompt del analista (esquema + criterios + evidencias)
  JUDGE_SYSTEM: str           # prompt del juez; DEBE empezar con "Eres un editor" (los dobles de prueba lo usan)
  build_user_message(objective: str, transcript: str, truncated: bool) -> str
Los textos de referencia están en harness/prompts/llm/*.md.
"""

from src.application.prompts import ANALYSIS_SYSTEM, JUDGE_SYSTEM, build_user_message


def test_analysis_prompt_declares_the_full_schema():
    for key in (
        "organizacion",
        "claridad",
        "repeticion",
        "palabras_repetidas",
        "fortalezas",
        "aspectos_por_mejorar",
        "recomendaciones",
        "evidencias",
        "afirmacion",
        "cita",
    ):
        assert key in ANALYSIS_SYSTEM, key


def test_analysis_prompt_demands_literal_quotes_and_forbids_invention():
    text = ANALYSIS_SYSTEM.lower()
    assert "textual" in text
    assert "no inventes" in text


def test_analysis_prompt_requires_json_only_and_spanish():
    text = ANALYSIS_SYSTEM.lower()
    assert "solo con json" in text
    assert "español" in text


def test_judge_prompt_contract():
    assert JUDGE_SYSTEM.startswith("Eres un editor")
    assert "resumen" in JUDGE_SYSTEM
    assert "datos objetivos" in JUDGE_SYSTEM.lower()


def test_user_message_sections():
    msg = build_user_message("Ritmo: 120 ppm", "Hola a todos.", truncated=False)
    assert "Ritmo: 120 ppm" in msg
    assert "Transcripción:" in msg and "Hola a todos." in msg
    assert "recortada" not in msg.lower()


def test_user_message_marks_truncation():
    assert "recortada" in build_user_message("x", "y", truncated=True).lower()

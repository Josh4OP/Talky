"""Ensamble de analistas LLM en paralelo, verificación de evidencias y síntesis con un juez."""

import json
import logging
import re
import statistics
from concurrent.futures import ThreadPoolExecutor

from pydantic import ValidationError

from src.application.prompts import JUDGE_SYSTEM
from src.application.services.verifier import drop_unverified, normalize, verification_rate, verify_evidences
from src.domain.entities.analysis import Analisis, Evidencia, Sintesis
from src.domain.exceptions import AllProvidersFailedError

logger = logging.getLogger("talky.ensemble")

_SCORED_FIELDS = ("organizacion", "claridad", "repeticion")
_LIST_FIELDS = ("fortalezas", "aspectos_por_mejorar", "recomendaciones")


def _clean_json(raw: str) -> str:
    raw = re.sub(r"^```(?:json)?|```$", "", raw.strip(), flags=re.M).strip()
    if not raw.startswith("{"):
        m = re.search(r"\{.*\}", raw, flags=re.S)
        if m:
            raw = m.group(0)
    return raw


def _parse_analisis(raw: str) -> Analisis:
    return Analisis.model_validate_json(_clean_json(raw))


def _parse_sintesis(raw: str) -> Sintesis:
    return Sintesis.model_validate_json(_clean_json(raw))


def _dedupe_by_quote(evidencias: list[Evidencia]) -> list[Evidencia]:
    seen: set[str] = set()
    unique = []
    for e in evidencias:
        key = normalize(e.cita)
        if key not in seen:
            seen.add(key)
            unique.append(e)
    return unique


class EnsembleAnalyzer:
    """Varios analistas opinan en paralelo; las citas se verifican y un juez sintetiza."""

    def __init__(self, providers, judge=None, min_ok: int = 1):
        if not providers:
            raise ValueError("Se necesita al menos un proveedor LLM")
        self.providers = list(providers)
        self.judge = judge
        self.min_ok = min_ok

    def _run_one(self, provider, system: str, user: str) -> Analisis:
        raw = provider.complete_json(system, user)
        try:
            return _parse_analisis(raw)
        except ValidationError:
            # Un solo reintento y solo por JSON inválido: un 429 o una caída no se reintentan (cuota limitada).
            logger.info("JSON inválido de %s; se reintenta una vez", provider.name)
            return _parse_analisis(provider.complete_json(system, user))

    def _run_all(self, system: str, user: str) -> tuple[dict[str, Analisis], dict[str, str]]:
        with ThreadPoolExecutor(max_workers=len(self.providers)) as pool:
            futures = [(p.name, pool.submit(self._run_one, p, system, user)) for p in self.providers]
        results: dict[str, Analisis] = {}
        errors: dict[str, str] = {}
        for name, future in futures:
            try:
                results[name] = future.result()
            except Exception as e:  # noqa: BLE001
                logger.warning("Analista %s falló (%s)", name, type(e).__name__)
                errors[name] = str(e)[:200] or type(e).__name__
        return results, errors

    def analyze(
        self, system: str, user: str, objective_data: str = "", transcript: str | None = None, verify: bool = True
    ) -> dict:
        results, errors = self._run_all(system, user)
        if len(results) < self.min_ok:
            raise AllProvidersFailedError(errors or {"ensamble": f"se requieren {self.min_ok} modelos"})

        verificacion = None
        if verify and transcript is not None:
            checked = {name: verify_evidences(a.evidencias, transcript) for name, a in results.items()}
            all_checked = [e for items in checked.values() for e in items]
            kept = {name: drop_unverified(items) for name, items in checked.items()}
            verificacion = {
                "tasa": verification_rate(all_checked),
                "descartadas": len(all_checked) - sum(len(items) for items in kept.values()),
            }
            results = {name: a.model_copy(update={"evidencias": kept[name]}) for name, a in results.items()}
        else:
            # Sin verificador, "verificada" no puede reflejar lo que el modelo diga de sí mismo.
            results = {
                name: a.model_copy(
                    update={"evidencias": [e.model_copy(update={"verificada": None}) for e in a.evidencias]}
                )
                for name, a in results.items()
            }

        evidencias = _dedupe_by_quote([e for a in results.values() for e in a.evidencias])
        return {
            "modelos_usados": list(results),
            "modelos_fallidos": errors,
            "puntajes": self._merge_scores(results),
            "sintesis": self._synthesize(results, objective_data),
            "evidencias": [e.model_dump() for e in evidencias],
            "verificacion": verificacion,
            "por_modelo": {name: a.model_dump() for name, a in results.items()},
        }

    @staticmethod
    def _merge_scores(results: dict[str, Analisis]) -> dict:
        out = {}
        for campo in _SCORED_FIELDS:
            vals = [getattr(a, campo).puntaje for a in results.values()]
            out[campo] = {
                "mediana": statistics.median(vals),
                "min": min(vals),
                "max": max(vals),
                "desacuerdo": (max(vals) - min(vals)) >= 3,
            }
        return out

    def _synthesize(self, results: dict[str, Analisis], objective_data: str) -> dict:
        if self.judge is not None and len(results) > 1:
            payload = {name: a.model_dump() for name, a in results.items()}
            user = (
                f"Datos objetivos:\n{objective_data}\n\n"
                f"Análisis de los modelos:\n{json.dumps(payload, ensure_ascii=False)}"
            )
            try:
                return _parse_sintesis(self.judge.complete_json(JUDGE_SYSTEM, user)).model_dump()
            except Exception as e:  # noqa: BLE001
                logger.warning("El juez falló (%s); se usa la unión simple", type(e).__name__)
        return self._simple_union(results)

    @staticmethod
    def _simple_union(results: dict[str, Analisis]) -> dict:
        merged: dict = {"resumen": ""}
        for campo in _LIST_FIELDS:
            seen, items = set(), []
            for a in results.values():
                for it in getattr(a, campo):
                    key = it.lower().strip()
                    if key not in seen:
                        seen.add(key)
                        items.append(it)
            merged[campo] = items
        return merged

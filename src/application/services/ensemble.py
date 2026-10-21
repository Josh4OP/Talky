import json
import logging
import re
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed

from src.domain.entities.analysis import Analisis, Sintesis

logger = logging.getLogger("talky.ensemble")

JUDGE_SYSTEM = """Eres un editor. Recibes varios análisis independientes de la
MISMA exposición oral, hechos por distintos modelos, junto con datos objetivos
(muletillas, ritmo, pausas). Sintetízalos en UN solo resultado.
Reglas:
- Une ideas equivalentes y elimina duplicados.
- Prioriza lo que varios modelos señalan en común.
- Descarta afirmaciones que contradigan los datos objetivos.
- Máximo 5 elementos por lista. Escribe en español, tono constructivo.
Responde SOLO con JSON con esta forma exacta:
{"resumen": "2-3 frases", "fortalezas": [], "aspectos_por_mejorar": [], "recomendaciones": []}"""


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


class EnsembleAnalyzer:
    def __init__(self, providers, judge=None, min_ok: int = 1):
        if not providers:
            raise ValueError("Se necesita al menos un proveedor LLM")
        self.providers = providers
        self.judge = judge
        self.min_ok = min_ok

    def _run_one(self, provider, system: str, user: str) -> Analisis:
        last = None
        for _ in range(2):
            try:
                return _parse_analisis(provider.complete_json(system, user))
            except Exception as e:
                last = e
        raise last

    def analyze(self, system: str, user: str, objective_data: str = "") -> dict:
        results: dict[str, Analisis] = {}
        errors: dict[str, str] = {}

        with ThreadPoolExecutor(max_workers=len(self.providers)) as ex:
            futures = {ex.submit(self._run_one, p, system, user): p for p in self.providers}
            for f in as_completed(futures):
                name = futures[f].name
                try:
                    results[name] = f.result()
                except Exception as e:
                    errors[name] = str(e)[:200]
                    logger.warning("Falló %s: %s", name, e)

        if len(results) < self.min_ok:
            raise RuntimeError(
                f"Solo respondieron {len(results)} de {len(self.providers)} modelos "
                f"(se requieren {self.min_ok}). Errores: {errors}")

        return {
            "modelos_usados": list(results),
            "modelos_fallidos": errors,
            "puntajes": self._merge_scores(results),
            "sintesis": self._synthesize(results, objective_data),
            "por_modelo": {k: v.model_dump() for k, v in results.items()},
        }

    @staticmethod
    def _merge_scores(results: dict[str, Analisis]) -> dict:
        out = {}
        for campo in ("organizacion", "claridad", "repeticion"):
            vals = [getattr(a, campo).puntaje for a in results.values()]
            out[campo] = {
                "mediana": statistics.median(vals),
                "min": min(vals),
                "max": max(vals),
                "desacuerdo": (max(vals) - min(vals)) >= 3,
            }
        return out

    def _synthesize(self, results: dict[str, Analisis], objective_data: str) -> dict:
        if self.judge and len(results) > 1:
            try:
                payload = {k: v.model_dump() for k, v in results.items()}
                user = (f"Datos objetivos:\n{objective_data}\n\n"
                        f"Análisis de los modelos:\n"
                        f"{json.dumps(payload, ensure_ascii=False)}")
                return _parse_sintesis(self.judge.complete_json(JUDGE_SYSTEM, user)).model_dump()
            except Exception as e:
                logger.warning("El juez falló, uso unión simple: %s", e)
        return self._simple_union(results)

    @staticmethod
    def _simple_union(results: dict[str, Analisis]) -> dict:
        merged: dict = {"resumen": ""}
        for campo in ("fortalezas", "aspectos_por_mejorar", "recomendaciones"):
            seen, items = set(), []
            for a in results.values():
                for it in getattr(a, campo):
                    key = it.lower().strip()
                    if key not in seen:
                        seen.add(key)
                        items.append(it)
            merged[campo] = items
        return merged
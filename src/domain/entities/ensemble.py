import json, logging, re, statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from src.domain.entities.analysis import Analisis

JUDGE_SYSTEM = """Eres un editor. Recibes varios análisis independientes de la
MISMA exposición oral, hechos por distintos modelos. Sintetízalos en UN solo
análisis final con el mismo formato JSON:
- Une ideas equivalentes y elimina duplicados.
- Prioriza lo que varios modelos señalan en común.
- Descarta afirmaciones que contradigan los datos objetivos (muletillas, ppm).
- Máximo 5 elementos por lista. Escribe en español. Responde SOLO con JSON."""

def _parse(raw: str) -> Analisis:
    raw = re.sub(r"^```(?:json)?|```$", "", raw.strip(), flags=re.M).strip()
    return Analisis.model_validate_json(raw)

class EnsembleAnalyzer:
    def __init__(self, providers, judge=None, min_ok=2):
        self.providers = providers
        self.judge = judge          # un LLMProvider (idealmente el más capaz)
        self.min_ok = min_ok

    def _run_one(self, p, system, user) -> Analisis:
        last = None
        for _ in range(2):          # 1 reintento si el JSON viene mal
            try:
                return _parse(p.complete_json(system, user))
            except Exception as e:
                last = e
        raise last

    def analyze(self, system: str, user: str) -> dict:
        results: dict[str, Analisis] = {}
        with ThreadPoolExecutor(max_workers=len(self.providers)) as ex:
            futs = {ex.submit(self._run_one, p, system, user): p for p in self.providers}
            for f in as_completed(futs):
                name = futs[f].name
                try:
                    results[name] = f.result()
                except Exception as e:
                    logging.warning("Falló %s: %s", name, e)

        if len(results) < self.min_ok:
            raise RuntimeError(f"Solo respondieron {len(results)} modelos")

        return {
            "modelos_usados": list(results),
            "puntajes": self._merge_scores(results),
            "sintesis": self._synthesize(results, user),
            "por_modelo": {k: v.model_dump() for k, v in results.items()},
        }

    def _merge_scores(self, results):
        out = {}
        for campo in ("organizacion", "claridad", "repeticion"):
            vals = [getattr(a, campo).puntaje for a in results.values()]
            out[campo] = {
                "mediana": statistics.median(vals),
                "min": min(vals), "max": max(vals),
                "desacuerdo": max(vals) - min(vals) >= 3,  # señal de baja confianza
            }
        return out

    def _synthesize(self, results, original_user):
        if self.judge:
            try:
                payload = {k: v.model_dump() for k, v in results.items()}
                user = (f"Datos objetivos:\n{original_user[:600]}\n\n"
                        f"Análisis de los modelos:\n{json.dumps(payload, ensure_ascii=False)}")
                return _parse(self.judge.complete_json(JUDGE_SYSTEM, user)).model_dump()
            except Exception as e:
                logging.warning("El juez falló, uso unión simple: %s", e)
        return self._simple_union(results)

    @staticmethod
    def _simple_union(results):
        merged = {}
        for campo in ("fortalezas", "aspectos_por_mejorar", "recomendaciones"):
            seen, items = set(), []
            for a in results.values():
                for it in getattr(a, campo):
                    key = it.lower().strip()
                    if key not in seen:
                        seen.add(key); items.append(it)
            merged[campo] = items
        return merged
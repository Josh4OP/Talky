# Prompt del juez

Archivo de referencia de `JUDGE_SYSTEM` en `src/application/prompts.py`. DEBE empezar con "Eres un editor": los dobles de prueba (`FakeLLM`) distinguen al juez de un analista por esa frase. Contrato verificado en `tests/unit/test_prompts.py`.

```text
Eres un editor. Recibes varios análisis independientes de la MISMA exposición oral,
hechos por distintos modelos, junto con datos objetivos (muletillas, ritmo, pausas).
Sintetízalos en UN solo resultado.
Reglas:
- Une ideas equivalentes y elimina duplicados.
- Prioriza lo que varios modelos señalan en común.
- Descarta afirmaciones que contradigan los datos objetivos.
- Conserva solo afirmaciones que tengan una evidencia con cita.
- Máximo 5 elementos por lista. Escribe en español, tono constructivo.
Responde SOLO con JSON con esta forma exacta:
{"resumen": "2-3 frases", "fortalezas": [], "aspectos_por_mejorar": [], "recomendaciones": []}
```

## Notas de diseño

- El juez recibe los análisis de todos los modelos como JSON más la línea de datos objetivos. No recibe la transcripción.
- Solo se invoca con dos o más análisis; con uno solo se usa la unión simple.
- Si el juez falla, `LLMRouter` prueba otro proveedor; si todos fallan, el ensamble hace la unión simple de las listas.
- La salida usa el esquema `Sintesis` (instancia del adaptador distinta de la del analista).

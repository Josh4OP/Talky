---
id: T18
title: Documentación, demo y endurecimiento
status: todo
phase: 4-cliente-y-calidad
depends_on: [T16, T17]
requirements: [RNF-01, RNF-02, RNF-03]
estimate: 5h
tests: [-]
touches: [README.md, docs/arquitectura.md, docs/guia-demo.md, scripts/demo.sh, Dockerfile, .env.example]
---
# T18 - Documentación, demo y endurecimiento

## Objetivo

Dejar el proyecto entregable: documentación que otra persona pueda seguir, una demo ensayada y verificada, y una pasada de endurecimiento sobre privacidad, errores y límites.

## Contexto

Checklists en `harness/checklists/definition-of-done.md` y `harness/checklists/demo-monday.md`. Riesgos de cuota y plazo en `harness/context/06-current-state.md`.

## Alcance

1. README final: qué es, arquitectura en un diagrama, instalación mínima y completa (con ML y embeddings), variables de entorno, cómo correr pruebas, cómo usar la API con `curl`, clasificador acustico como trabajo futuro, cómo correr la app, aviso de privacidad, limitaciones conocidas (identidad declarada, cuotas de Groq, tamaño de los datos).
2. `docs/arquitectura.md`: diagramas Mermaid de capas, flujo de una petición y degradación; decisiones principales (resumen de `harness/context/12-decisions.md`).
3. `docs/guia-demo.md` y `scripts/demo.sh`: guion de 5 minutos, audio de ejemplo propio de una persona que dio su permiso, y comandos para levantar API y app.
4. Endurecimiento: revisar que no se registre contenido de usuario, que los mensajes de error sean claros, que el tiempo de espera de red sea explícito, que CORS esté documentado, que `.env.example` esté completo y sin valores reales.
5. Dockerfile opcional (imagen con requisitos del núcleo y `uvicorn`), solo si el equipo lo quiere.
6. Ensayo de la demo completa dos veces siguiendo `harness/checklists/demo-monday.md`, anotando incidencias.

No hacer: funciones nuevas. Lo que falte de otras tareas se reporta, no se improvisa aquí.

## Contrato

- Todo comando documentado se probó en un entorno limpio.
- El README no promete funciones que no existen.
- El informe académico puede enlazar `docs/evaluacion.md` y `docs/arquitectura.md` como evidencia.

## Criterios de aceptación

1. Una persona ajena al código instala y levanta la API siguiendo solo el README, en menos de 15 minutos.
2. `python harness/tools/check_harness.py` y la suite completa están en verde.
3. La demo del lunes funciona dos veces seguidas con Groq y una con `TRANSCRIBER=local`.
4. `grep -rn "print(" src/` no muestra impresiones de depuración y los logs no contienen texto de usuarios.
5. El checklist `harness/checklists/demo-monday.md` está completo.

## Pruebas

```bash
python harness/tools/check_harness.py
python -m pytest -q
bash scripts/demo.sh        # humo de la demo contra la API local
```

## Definición de hecho

- [ ] Verificación de la tarea: `python harness/tools/check_harness.py && python -m pytest -q`.
- [ ] Suite completa sin regresiones: `python -m pytest -q`.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] Reglas de capas respetadas (`/verify`) y sin cambios fuera de alcance.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado: `python harness/tools/tasks.py status T18 done`.
- [ ] Commit(s) convencional(es) `tipo(T18): descripción`.

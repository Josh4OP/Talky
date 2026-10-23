---
id: T00
title: Título corto en imperativo
status: todo
phase: 1-nucleo
depends_on: []
requirements: [RF-01]
estimate: 2h
tests: [tests/unit/test_ejemplo.py]
touches: [src/ruta/modulo.py]
---

# T00 - Título corto en imperativo

## Objetivo

Una o dos frases: qué valor entrega esta tarea y para quién.

## Contexto

Por qué existe, qué documentos de `harness/context/` hay que leer, qué hay hoy en el código.

## Alcance

Hacer:

1. Paso concreto.
2. Paso concreto.

No hacer: lo que podría tentar pero queda fuera.

## Contrato

Firmas públicas, reglas de negocio y casos borde. Si ya están en `harness/context/10-module-contracts.md`, enlázalo y resume solo los puntos finos.

## Criterios de aceptación

1. Criterio verificable (comando o comportamiento observable).
2. Criterio verificable.

## Pruebas

```bash
python -m pytest tests/unit/test_ejemplo.py -q
```

## Definición de hecho

- [ ] Pruebas de la tarea en verde.
- [ ] Suite completa sin regresiones.
- [ ] `ruff check .` y `ruff format --check .` sin diferencias.
- [ ] `/review` sin bloqueantes.
- [ ] Estado actualizado a `done`.

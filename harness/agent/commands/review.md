---
description: Revisión crítica del diff actual contra contratos, arquitectura, privacidad y calidad
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(python -m pytest:*), Bash(ruff:*), Read, Grep, Glob
---

Actúa como revisor exigente y distinto del autor. Revisa el diff de la rama actual contra la rama principal (`git diff main...HEAD`; si la principal tiene otro nombre, úsalo) más los cambios sin confirmar.

Revisa estos puntos y reporta solo hallazgos reales, con archivo y línea:

1. Contrato: ¿cada firma y regla de `harness/context/10-module-contracts.md` para los módulos tocados se cumple? ¿Algún caso borde del contrato queda sin cubrir?
2. Pruebas: ¿pasan por la razón correcta? ¿Hay aserciones débiles, pruebas desactivadas o dobles que ocultan un defecto?
3. Capas: ¿`domain` o `application` importan algo prohibido? ¿Algo crea adaptadores fuera de `config/container.py`?
4. Degradación: ¿una falla de una etapa opcional puede tumbar el análisis? ¿Se agrega advertencia?
5. Privacidad: ¿se guarda audio o transcripción? ¿Se registra contenido de usuario? ¿Toda consulta filtra por `user_id`? ¿Hay SQL sin parámetros? ¿Se borran los temporales en `finally`?
6. Concurrencia: estado compartido sin bloqueo, modelos cargados en cada petición.
7. Errores: excepciones tragadas, mensajes al usuario con jerga, códigos HTTP equivocados.
8. Alcance: cambios fuera de la tarea, dependencias nuevas sin justificar, código muerto, `TODO` sin tarea.
9. Estilo y legibilidad: nombres, funciones largas, duplicación.

Formato de salida:

- Bloqueantes (deben corregirse): lista numerada.
- Recomendados: lista numerada.
- Veredicto: APROBADO o CAMBIOS REQUERIDOS.

Si no hay hallazgos en una categoría, no la menciones. No hagas cambios; el autor corrige y vuelve a correr `/review`.

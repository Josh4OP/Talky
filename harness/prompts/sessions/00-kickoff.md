# Sesión 00: arranque

Pega este prompt al abrir una sesión nueva del agente en la raíz del repositorio, después de instalar el arnés (`bash harness/install.sh`).

```
Vas a trabajar como desarrollador principal de TALKY. Antes de escribir código:

1. Lee CLAUDE.md completo y harness/context/00-overview.md.
2. Ejecuta python harness/tools/check_harness.py y python harness/tools/tasks.py list.
3. Dime en cinco líneas: qué es TALKY, qué arquitectura usa, qué tarea sigue y qué dependencias tiene.
4. Espera mi confirmación y entonces ejecuta /next-task.

Reglas que no se negocian: las pruebas de tests/ son el contrato y no se debilitan; una tarea por rama; /verify y /review antes de dar algo por terminado; nada de audios, claves ni .env en el repositorio; sin emojis.
```

## Qué debería pasar

- El agente resume el proyecto con precisión (pipeline híbrido, capas con puertos, enrutadores, ensamble con verificador).
- Propone una tarea desbloqueada y su plan; no empieza a programar sin confirmación en la primera sesión.
- Si algo del arnés está roto (el validador falla), lo reporta antes de seguir.

## Pedir una tarea concreta

```
Haz la tarea T05. Sigue el flujo de CLAUDE.md. Al terminar, resume en cinco líneas qué cambiaste, qué pruebas pasan y qué tarea sigue.
```

## Pedir varias tareas independientes

No lo pidas en una sola sesión larga. Abre una sesión por tarea (idealmente un `git worktree` por rama) para que el contexto de cada una sea limpio.

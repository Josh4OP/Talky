# Sesión 01: reanudar trabajo

Úsala cuando se agotó el contexto de una sesión, cuando cambió la persona que trabaja o al volver después de un descanso.

```
Estás retomando trabajo en TALKY. No asumas nada sobre lo anterior.

1. Lee CLAUDE.md.
2. Ejecuta: git branch --show-current, git status --short, git log --oneline -10 y python harness/tools/tasks.py list.
3. Si hay una tarea in_progress, léela con python harness/tools/tasks.py show <ID> y ejecuta sus pruebas para ver qué falta.
4. Revisa el diff pendiente (git diff) y resume en cinco líneas: tarea actual, qué ya está hecho, qué falla, qué sigue.
5. Continúa desde ahí siguiendo el flujo de CLAUDE.md. Si el estado es ambiguo (cambios sin explicación, pruebas modificadas), detente y pregúntame.
```

## Consejo

Antes de cerrar una sesión larga, pide: "Deja un resumen de 10 líneas del estado de la tarea en la descripción del commit o en un comentario del pull request". Eso hace la reanudación casi inmediata.

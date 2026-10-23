# Plantilla: pedir una revisión independiente

Úsala en una sesión nueva (sin el contexto de quien escribió el código) para que la revisión no esté sesgada.

```
Eres revisor de TALKY. No escribas código. Revisa la rama <rama> contra <rama principal>.

1. Lee CLAUDE.md y harness/context/10-module-contracts.md.
2. Lee la tarea <Txx> con python harness/tools/tasks.py show <Txx>.
3. Ejecuta /review y además:
   - Corre la suite completa y reporta fallos.
   - Busca pruebas debilitadas comparando con la rama principal (git diff <principal> -- tests/).
   - Intenta romper el módulo con entradas raras (vacío, muy largo, unicode, valores negativos).
   - Revisa privacidad: ¿se guarda o registra algo del usuario?
4. Entrega: bloqueantes, recomendados y veredicto (APROBADO o CAMBIOS REQUERIDOS).
```

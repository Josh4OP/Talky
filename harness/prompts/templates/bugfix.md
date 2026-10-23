# Plantilla: corrección de un defecto

Usa este texto como prompt cuando algo falla fuera del flujo normal de una tarea.

```
Hay un defecto en TALKY. Sigue este orden y no te saltes pasos.

Síntoma: <qué se observa, con el mensaje de error o el resultado incorrecto>
Cómo reproducirlo: <comando o petición exacta>
Esperado: <qué debería pasar según el contrato (cita el documento o la prueba)>
Contexto adicional: <versión, archivo de audio de prueba, variables de entorno relevantes, sin claves>

1. Reproduce el defecto y escribe una prueba que falle por esa causa (en el directorio de pruebas que corresponda). No arregles nada todavía.
2. Encuentra la causa raíz leyendo el código; explícala en dos frases.
3. Arregla la causa, no el síntoma. Cambio mínimo.
4. Corre /verify. La prueba nueva debe pasar y la suite completa seguir en verde.
5. Corre /review.
6. Commit con mensaje fix(Txx): ... referenciando la tarea del módulo afectado.
7. Si el defecto revela un hueco en el contrato, propón la actualización de harness/context/10-module-contracts.md.
```

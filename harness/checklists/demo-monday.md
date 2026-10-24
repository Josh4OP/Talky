# Lista de verificación de la demo (lunes 26 de octubre de 2026)

Ensaya esta lista dos veces: el domingo por la noche y el lunes antes de la entrega.

## Dos días antes (sábado 24)

- [ ] La rama principal tiene el hito de backend: suite de aceptación en verde.
- [ ] `.env` de demostración con `GROQ_API_KEY` válida y modelos vigentes (verificados en la consola de Groq ese mismo día).
- [ ] Cuotas revisadas: la consola de Groq muestra margen para unas 30 transcripciones.
- [ ] Un audio de demostración de 3 a 5 minutos con permiso de quien habla, con muletillas reales y al menos un tatareo.
- [ ] Segundo audio corto (30 a 60 s) de respaldo para pruebas rápidas.

## Un día antes (domingo 25)

- [ ] Instalación en limpio en una máquina distinta de la de desarrollo, siguiendo solo el README.
- [ ] `python -m pytest -q` en verde en esa máquina.
- [ ] Modo con Groq: análisis completo en menos de 60 segundos.
- [ ] Modo sin red o con `TRANSCRIBER=local`: funciona (más lento) y muestra la advertencia de respaldo.
- [ ] `ENABLE_EVENT_CLASSIFIER=false`: el clasificador acústico está aplazado (fuera del MVP, D-11).
- [ ] Embeddings descargados una vez (`ENABLE_TEXT_EMBEDDINGS=true`) para que la primera petición no espere la descarga; si no, apagada.
- [ ] La app Flutter instalada en el teléfono o emulador, apuntando a la IP correcta de la API.
- [ ] El historial muestra al menos dos análisis previos.
- [ ] Capturas de pantalla y una grabación de la demo funcionando, por si falla la red en vivo.

## El día de la entrega, 30 minutos antes

- [ ] Batería, cargador y datos móviles como respaldo de la red.
- [ ] API levantada (`uvicorn main:app --host 0.0.0.0`) y `GET /health` responde.
- [ ] Una petición de humo con el audio corto: 201 y puntajes.
- [ ] La app envía una petición real de punta a punta.
- [ ] Informe y repositorio abiertos: README, `docs/arquitectura.md`, `docs/evaluacion.md`.
- [ ] Ningún `.env` ni clave visible en pantalla durante la presentación.

## Guion de la demostración (5 minutos)

1. Problema (30 s): estudiantes con muletillas, nervios y falta de retroalimentación.
2. Arquitectura en una diapositiva (60 s): pipeline híbrido; Whisper en Groq; embeddings; ensamble de LLM con verificador de citas. Mencionar el clasificador acústico como mejora futura.
3. Demo en vivo (2 min): subir el audio, mostrar puntajes, muletillas, ritmo, evidencias citadas, historial.
4. Resultados medidos (60 s): tablas de `docs/evaluacion.md` (WER, F1 de muletillas, tasa de verificación de citas).
5. Limitaciones y trabajo futuro (30 s): identidad declarada, pocos hablantes, cuotas gratuitas; autenticación, más datos, grabación en la app.

## Si algo falla en vivo

| Falla | Qué hacer |
|---|---|
| Groq responde 429 o no hay red | La app ya muestra la advertencia de respaldo si hay Whisper local; si no, pasar al video de respaldo |
| La API no levanta | Revisar `.env` y la salida de `uvicorn`; mostrar la grabación de respaldo |
| El teléfono no alcanza la API | Usar el emulador o abrir `/docs` desde el navegador del portátil |
| El análisis tarda demasiado | Explicar el costo del audio largo y repetir con el audio corto |

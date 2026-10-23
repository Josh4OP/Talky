from src.application.services.ensemble import EnsembleAnalyzer
from src.application.services.filler_detector import detect_fillers
from src.application.services.metrics import pause_stats, words_per_minute

SYSTEM = """Eres un coach de oratoria para universitarios. Analizas la transcripción
de una exposición oral (transcrita automáticamente, puede tener errores menores).
Responde SOLO con JSON con esta forma exacta:
{
 "organizacion": {"puntaje": 1-10, "comentario": ""},
 "claridad": {"puntaje": 1-10, "comentario": ""},
 "repeticion": {"puntaje": 1-10, "comentario": "", "palabras_repetidas": []},
 "fortalezas": [],
 "aspectos_por_mejorar": [],
 "recomendaciones": []
}
Criterios:
- organizacion: ¿hay introducción, desarrollo y cierre? ¿las ideas siguen un orden lógico?
- claridad: ¿se expresa de forma comprensible y precisa?
- repeticion: 10 = casi no repite; 1 = repite palabras o ideas en exceso.
Los puntajes son números enteros. Sé específico, constructivo y escribe en español.
No inventes datos que no estén en la transcripción."""


class AnalyzePresentation:
    def __init__(self, transcriber, ensemble: EnsembleAnalyzer, max_chars: int = 12000):
        self.transcriber = transcriber
        self.ensemble = ensemble
        self.max_chars = max_chars

    def execute(self, audio_path: str) -> dict:
        tr = self.transcriber.transcribe(audio_path)
        if not tr.text.strip():
            raise ValueError("No se detectó voz en el audio")

        fillers = detect_fillers(tr.text)
        wpm = words_per_minute(tr.text, tr.duration)
        pausas = pause_stats(tr.segments)

        text = tr.text
        truncated = len(text) > self.max_chars
        if truncated:
            text = text[: self.max_chars]

        objective = (
            f"Duración: {tr.duration:.0f} s | Ritmo: {wpm} palabras/min | "
            f"Pausas largas: {pausas['pausas_largas']} | Muletillas: {fillers}"
        )
        user_msg = f"{objective}\n\nTranscripción:\n{text}"
        if truncated:
            user_msg += "\n\n[Transcripción recortada por longitud]"

        result = self.ensemble.analyze(SYSTEM, user_msg, objective_data=objective)

        return {
            "duracion_s": round(tr.duration, 1),
            "ppm": wpm,
            "pausas": pausas,
            "muletillas": fillers,
            "transcripcion_recortada": truncated,
            **result,
        }

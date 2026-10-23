from pydantic import BaseModel, Field, field_validator


class Aspecto(BaseModel):
    puntaje: int = Field(ge=1, le=10)
    comentario: str = ""

    @field_validator("puntaje", mode="before")
    @classmethod
    def _redondear(cls, v):
        return round(float(v))


class Repeticion(Aspecto):
    palabras_repetidas: list[str] = []


class Analisis(BaseModel):
    organizacion: Aspecto
    claridad: Aspecto
    repeticion: Repeticion
    fortalezas: list[str] = []
    aspectos_por_mejorar: list[str] = []
    recomendaciones: list[str] = []


class Sintesis(BaseModel):
    resumen: str = ""
    fortalezas: list[str] = []
    aspectos_por_mejorar: list[str] = []
    recomendaciones: list[str] = []

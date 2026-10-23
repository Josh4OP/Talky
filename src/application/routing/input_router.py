"""Enrutamiento por reglas de la entrada: rechazar, elegir transcriptor y decidir si comprimir."""

from dataclasses import dataclass, field

QUOTA_WARNING = (
    "La cuota gratuita de transcripción en la nube no alcanza para este audio; "
    "se usa la transcripción local, que puede tardar más."
)
QUIET_WARNING = "El volumen de la grabación es muy bajo; la transcripción puede ser menos precisa."


@dataclass(frozen=True)
class AudioInfo:
    duration_s: float
    size_bytes: int
    rms_dbfs: float | None = None


@dataclass(frozen=True)
class RoutingSettings:
    groq_enabled: bool = False
    groq_max_bytes: int = 25 * 1024 * 1024
    min_duration_s: float = 5.0
    max_duration_s: float = 2700.0
    quiet_dbfs: float = -45.0
    groq_remaining_audio_s: float | None = None


@dataclass
class RoutingDecision:
    transcriber: str
    compress: bool = False
    warnings: list[str] = field(default_factory=list)
    reject_code: str | None = None
    reject_reason: str | None = None


def _format_duration(seconds: float) -> str:
    if seconds < 60:
        return f"{seconds:.0f} segundos"
    return f"{seconds / 60:.0f} minutos"


def _rejection(info: AudioInfo, settings: RoutingSettings) -> RoutingDecision | None:
    if info.duration_s < settings.min_duration_s:
        reason = (
            f"El audio dura {_format_duration(info.duration_s)} y el mínimo es "
            f"{_format_duration(settings.min_duration_s)}. Graba una exposición más larga."
        )
        return RoutingDecision(transcriber="none", reject_code="too_short", reject_reason=reason)
    if info.duration_s > settings.max_duration_s:
        reason = (
            f"El audio dura {_format_duration(info.duration_s)} y el máximo es "
            f"{_format_duration(settings.max_duration_s)}. Divide la grabación en partes."
        )
        return RoutingDecision(transcriber="none", reject_code="too_long", reject_reason=reason)
    return None


def route_input(info: AudioInfo, settings: RoutingSettings) -> RoutingDecision:
    rejection = _rejection(info, settings)
    if rejection is not None:
        return rejection

    warnings: list[str] = []
    transcriber = "groq" if settings.groq_enabled else "local"
    quota = settings.groq_remaining_audio_s
    if transcriber == "groq" and quota is not None and quota < info.duration_s:
        transcriber = "local"
        warnings.append(QUOTA_WARNING)
    if info.rms_dbfs is not None and info.rms_dbfs < settings.quiet_dbfs:
        warnings.append(QUIET_WARNING)

    compress = transcriber == "groq" and info.size_bytes > settings.groq_max_bytes
    return RoutingDecision(transcriber=transcriber, compress=compress, warnings=warnings)

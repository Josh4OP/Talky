"""Excepciones del dominio de TALKY."""


class TalkyError(Exception):
    """Base de todos los errores propios."""


class ConfigurationError(TalkyError, ValueError):
    """Configuración inválida o incompleta."""


class InvalidAudioError(TalkyError, ValueError):
    """Audio ilegible, sin voz o fuera de los límites permitidos."""


class ProviderError(TalkyError):
    """Fallo de un proveedor externo."""


class RateLimitedError(ProviderError):
    """El proveedor rechazó la petición por cuota (HTTP 429)."""

    def __init__(self, message: str = "Proveedor limitado por cuota", retry_after: float | None = None):
        super().__init__(message)
        self.retry_after = retry_after


class AllProvidersFailedError(TalkyError, RuntimeError):
    """Ningún proveedor pudo responder."""

    def __init__(self, errors: dict[str, str]):
        self.errors = dict(errors)
        super().__init__("; ".join(f"{name}: {error}" for name, error in self.errors.items()))

"""Punto de entrada del servidor: `uvicorn main:app --host 0.0.0.0`."""

import logging

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None

if load_dotenv is not None:
    load_dotenv()

from src.config.container import build_container  # noqa: E402
from src.config.settings import Settings  # noqa: E402
from src.presentation.app import create_app  # noqa: E402

logging.basicConfig(level=logging.INFO)

app = create_app(build_container(Settings.from_env()))

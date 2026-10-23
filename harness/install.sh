#!/usr/bin/env bash
# Instala el arnés en el repositorio que contiene esta carpeta (harness/).
# Equivale a: python harness/tools/install.py "$@"
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python_bin="${PYTHON:-python3}"
command -v "$python_bin" >/dev/null 2>&1 || python_bin=python
exec "$python_bin" "$here/tools/install.py" "$@"

# Atajos de TALKY. En Windows usa los comandos equivalentes o instala `make` (por ejemplo con Git Bash o Chocolatey).
PY ?= python

.PHONY: install test lint format verify run tasks next eval-text check-harness

install:
	$(PY) -m pip install -r requirements-dev.txt

test:
	$(PY) -m pytest -q

lint:
	ruff check . && ruff format --check .

format:
	ruff check --fix . && ruff format .

verify: lint test check-harness

run:
	uvicorn main:app --reload

tasks:
	$(PY) harness/tools/tasks.py list

next:
	$(PY) harness/tools/tasks.py next

eval-text:
	$(PY) evals/run_eval.py --mode text --manifest evals/dataset/manifest.json

check-harness:
	$(PY) harness/tools/check_harness.py

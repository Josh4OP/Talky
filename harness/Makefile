# Desarrollo del propio arnés (no del producto). Ejecutar desde la carpeta harness/.
PY ?= python

.PHONY: check test zip install

check:
	$(PY) tools/check_harness.py

test:
	$(PY) -m pytest harness_tests -q -p no:cacheprovider

zip:
	$(PY) tools/make_zip.py

install:
	$(PY) tools/install.py

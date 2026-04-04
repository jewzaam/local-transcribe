# Makefile for local-transcribe

.PHONY: check help install install-dev install-no-deps uninstall clean format format-check lint typecheck test test-verbose coverage complexity run

# Normalize HOME to forward slashes (no-op on Unix, fixes Windows backslashes)
HOME_DIR := $(subst \,/,$(HOME))

# Use shared ~/.venv/ap if it exists, otherwise local .venv
ifeq ($(OS),Windows_NT)
    VENV_DIR ?= $(if $(wildcard $(HOME_DIR)/.venv/ap/Scripts/python.exe),$(HOME_DIR)/.venv/ap,.venv)
    PYTHON ?= $(VENV_DIR)/Scripts/python.exe
else
    VENV_DIR ?= $(if $(wildcard $(HOME_DIR)/.venv/ap/bin/python),$(HOME_DIR)/.venv/ap,.venv)
    PYTHON ?= $(VENV_DIR)/bin/python
endif

$(info venv: $(VENV_DIR))

check: format lint typecheck test coverage  ## Run format, lint, typecheck, test, coverage (default)

.DEFAULT_GOAL := check

help:  ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

$(PYTHON):
	python3 -m venv $(VENV_DIR)

install: $(PYTHON)  ## Install package
	$(PYTHON) -m pip install .

install-dev: $(PYTHON)  ## Install in editable mode with dev deps
	$(PYTHON) -m pip install -e ".[dev]"

install-no-deps: $(PYTHON)  ## Install in editable mode without dependencies
	$(PYTHON) -m pip install -e . --no-deps

uninstall:  ## Uninstall package
	$(PYTHON) -m pip uninstall -y local-transcribe

clean:  ## Remove build artifacts and caches
	rm -rf build/ dist/ *.egg-info
	find . -type d -name __pycache__ -exec rm -r {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

format: install-dev  ## Format code with black
	$(PYTHON) -m black local_transcribe local_transcribe_ui tests

format-check: install-dev  ## Check formatting without modifying files
	$(PYTHON) -m black --check local_transcribe local_transcribe_ui tests

lint: install-dev  ## Lint with flake8
	$(PYTHON) -m flake8 --max-line-length=88 --extend-ignore=E203,W503 local_transcribe local_transcribe_ui tests

typecheck: install-dev  ## Type check with mypy
	$(PYTHON) -m mypy local_transcribe local_transcribe_ui

test: install-dev  ## Run pytest
	$(PYTHON) -m pytest

test-verbose: install-dev  ## Run pytest with verbose output
	$(PYTHON) -m pytest -v

coverage: install-dev  ## Run pytest with coverage
	$(PYTHON) -m pytest --cov=local_transcribe --cov=local_transcribe_ui --cov-report=term

complexity: install-dev  ## Check cyclomatic complexity (max 10 per function)
	$(PYTHON) -m radon cc local_transcribe local_transcribe_ui -n C -s

run: install-dev  ## Run the voice recording UI
	$(PYTHON) -m local_transcribe_ui

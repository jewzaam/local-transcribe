# Makefile for local-transcribe

-include make/pipx.mk

.PHONY: check help install install-dev install-no-deps uninstall clean format format-check lint typecheck test test-verbose coverage complexity mutation mutation-report run

PACKAGE_NAME ?= local_transcribe local_transcribe_ui

ifeq ($(OS),Windows_NT)
    VENV_DIR ?= .venv
    PYTHON ?= $(VENV_DIR)/Scripts/python.exe
else
    VENV_DIR ?= .venv
    PYTHON ?= $(VENV_DIR)/bin/python
endif

$(info venv: $(VENV_DIR))

check: format lint typecheck test coverage  ## Run format, lint, typecheck, test, coverage (default)

.DEFAULT_GOAL := check

help:  ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

$(PYTHON):
	python3 -m venv $(VENV_DIR)

install: $(PYTHON)  ## Install package
	$(PYTHON) -m pip install .

install-dev: $(PYTHON)  ## Install in editable mode with dev deps
	$(PYTHON) -m pip install -e ".[dev]"

install-no-deps: $(PYTHON)  ## Install in editable mode without dependencies
	$(PYTHON) -m pip install -e . --no-deps

uninstall: $(PYTHON)  ## Uninstall package
	$(PYTHON) -m pip uninstall -y local-transcribe

clean:  ## Remove build artifacts and caches
	rm -rf build/ dist/ *.egg-info
	find . -type d -name __pycache__ -exec rm -r {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

format: install-dev  ## Format code with black
	$(PYTHON) -m black $(PACKAGE_NAME) tests

format-check: install-dev  ## Check formatting without modifying files
	$(PYTHON) -m black --check $(PACKAGE_NAME) tests

lint: install-dev  ## Lint with flake8
	$(PYTHON) -m flake8 --max-line-length=88 --extend-ignore=E203,W503 $(PACKAGE_NAME) tests

typecheck: install-dev  ## Type check with mypy
	$(PYTHON) -m mypy $(PACKAGE_NAME)

test: install-dev  ## Run pytest
	$(PYTHON) -m pytest

test-verbose: install-dev  ## Run pytest with verbose output
	$(PYTHON) -m pytest -v

coverage: install-dev  ## Run pytest with coverage (50% threshold — GUI code is untestable without display)
	$(PYTHON) -m pytest --cov=local_transcribe --cov=local_transcribe_ui --cov-report=term --cov-fail-under=50

complexity: install-dev  ## Check cyclomatic complexity (max 10 per function)
	$(PYTHON) -m radon cc $(PACKAGE_NAME) -n C -s

mutation: install-dev  ## Run mutation testing (not part of check — run on-demand)
	$(PYTHON) -m mutmut run --CI --paths-to-mutate "local_transcribe"

mutation-report: $(PYTHON)  ## Show results of last mutation run
	$(PYTHON) -m mutmut results

run: install-dev  ## Run the voice recording UI
	$(PYTHON) -m local_transcribe_ui record --model small

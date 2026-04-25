# Optional target: install CLI tools globally via pipx.
# Requires: python3 -m pip install --user pipx

.PHONY: install-pipx install-pipx-cuda uninstall-pipx

# PROJECT_NAME is the distribution name from [project] name in pyproject.toml.
# This may differ from PACKAGE_NAME (the Python module name) — e.g., my-tool vs my_tool.
PROJECT_NAME ?= local-transcribe

install-pipx:  ## Install globally via pipx
	python3 -m pipx install . --force

install-pipx-cuda:  ## Inject CUDA runtime libs into pipx install
	python3 -m pipx inject $(PROJECT_NAME) nvidia-cublas-cu12 nvidia-cudnn-cu12

uninstall-pipx:  ## Uninstall global pipx install
	python3 -m pipx uninstall $(PROJECT_NAME)

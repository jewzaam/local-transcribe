# local-transcribe

Chunked local speech-to-text using faster-whisper. Two packages in one repo:

- **`local_transcribe/`** — library: audio recording, silence detection, chunked transcription
- **`local_transcribe_ui/`** — CLI + tkinter GUI: `local-transcribe record`, `transcribe`, `devices`

## Build & Test

```bash
make install-dev   # editable install with dev deps into .venv
make check         # format + lint + typecheck + test + coverage (default target)
make pipx          # install globally via pipx (no venv needed)
```

Individual targets: `make format`, `make lint`, `make typecheck`, `make test`, `make coverage`.

Integration tests (require model download) are excluded by default. Run with: `python -m pytest -m integration`.

## Architecture

- **`transcription.py`** — model loading (cached by `(model_size, device, compute_type)` key), WAV transcription, background preloading
- **`chunking.py`** — `SilenceDetector` + `ChunkManager` for real-time chunked transcription
- **`recording.py`** — `RecordingSession` wrapping sounddevice for mic capture
- **`__main__.py`** — CLI entry point with `--config PATH` support for JSON config files
- **`controller.py`** — `AppController` orchestrating GUI recording sessions
- **`protocol.py`** — stdout markers (`[BEGIN version=X.Y.Z]`, `[END]`, `[CANCEL]`) for machine-readable output

## Config file

`--config PATH` loads a JSON file. Config keys match `_CONFIG_DEFAULTS` in `__main__.py`:

```json
{
    "model": "small",
    "compute_device": "cpu",
    "compute_type": "int8",
    "silence_threshold": 0.08,
    "silence_duration": 1.0,
    "min_chunk_seconds": 10.0
}
```

CLI args that overlap with config keys are rejected when `--config` is used — no precedence ambiguity.

## CPU-only systems

Defaults are already CPU-safe (`compute_device: "cpu"`, `compute_type: "int8"`). No CUDA libraries needed. The `make pipx-cuda` target exists for systems with CUDA but is not required.

## Version

Single source of truth: `local_transcribe/__init__.py` (`__version__`). Currently `0.4.0`.

## Voice skill integration

The `/voice` Claude Code skill invokes:
```
local-transcribe record --config ~/.config/local-transcribe-config.json --debug --log-file ~/.config/claude-skill-voice/debug.log
```

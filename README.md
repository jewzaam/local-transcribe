# local-transcribe

[![test](https://github.com/jewzaam/local-transcribe/actions/workflows/test.yml/badge.svg)](https://github.com/jewzaam/local-transcribe/actions/workflows/test.yml) [![quality](https://github.com/jewzaam/local-transcribe/actions/workflows/quality.yml/badge.svg)](https://github.com/jewzaam/local-transcribe/actions/workflows/quality.yml)
[![Python 3.14](https://img.shields.io/badge/python-3.14-blue.svg)](https://www.python.org/downloads/) [![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)

Local speech-to-text using faster-whisper. Record from a microphone with a tkinter GUI, transcribe WAV files from the command line, or use the engine as a library in your own application.

## Documentation

- **[Architecture](docs/architecture.md)** — engine/UI separation, module responsibilities
- **[CLI Reference](docs/cli.md)** — subcommands, options, examples
- **[Configuration](docs/config.md)** — config file, GPU setup, silence tuning

## Overview

- Records audio with silence detection and chunked background transcription
- Tkinter GUI with level meter, progress bars, pause/resume/cancel
- Pure CLI mode for transcribing existing WAV files
- Reusable engine library (`local_transcribe`) with no GUI dependency
- Thread-safe Whisper model caching with background preload
- Configurable model size, device, compute type, beam size

## Installation

### Development

```bash
git clone https://github.com/jewzaam/local-transcribe.git
cd local-transcribe
make install-dev
```

### Global (pipx)

```bash
make install-pipx       # install CLI globally
make install-pipx-cuda  # inject NVIDIA CUDA libs for GPU acceleration
```

### From Git

```bash
pip install git+https://github.com/jewzaam/local-transcribe.git
```

## Usage

### Record with GUI

```bash
local-transcribe record
local-transcribe record --model large --compute-device cuda --compute-type float16
local-transcribe record --config ~/.config/local-transcribe-config.json
```

### Transcribe a WAV file

```bash
local-transcribe transcribe recording.wav
local-transcribe transcribe recording.wav --model large --compute-device cuda --compute-type float16
```

### List audio devices

```bash
local-transcribe devices
```

### As an embedded UI

```python
from local_transcribe_ui import RecordingController

def on_transcript(text: str):
    chat.send_message(text)

controller = RecordingController(
    root,  # existing tk.Tk root
    on_done=on_transcript,
    compute_device="cuda",
    compute_type="float16",
)
controller.start()
# Window appears, user records, on_done fires, window closes
```

## Development

```bash
make help        # show all targets
make check       # format, lint, typecheck, test, coverage
make test-unit   # pytest (unit tests only)
make run         # launch the recording GUI
```

Integration tests (require model download): `pytest -m integration`

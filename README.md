# local-transcribe

Chunked local speech-to-text engine using [faster-whisper](https://github.com/SYSTRAN/faster-whisper). Records audio from a microphone, detects silence boundaries, and transcribes chunks in the background — no cloud API required.

Designed as a reusable library with no GUI dependency. Frontends (CLI, tkinter, web) import and wire up the engine.

## Install

```bash
pip install -e ".[dev]"
```

## Public API

- **`RecordingSession`** — audio capture with level metering and silence-triggered flushing
- **`ChunkManager`** — background transcription worker thread
- **`SilenceDetector`** — silence gap detection for automatic chunk boundaries
- **`transcribe_wav(path)`** / **`transcribe_audio(array)`** — direct transcription
- **`get_or_create_model()`** — cached Whisper model access
- **`save_wav_to(audio, path)`** — WAV file I/O

## Usage

```python
from local_transcribe import (
    ChunkManager,
    RecordingSession,
    SilenceDetector,
    start_whisper_preload,
)

# Preload model in background
start_whisper_preload()

# Set up chunked transcription
mgr = ChunkManager(model_size="small")
det = SilenceDetector()
session = RecordingSession(chunk_manager=mgr, silence_detector=det)

mgr.start_worker()
session.start()

# ... recording happens, silence triggers automatic flushes ...

audio = session.stop()
mgr.finish()
print(mgr.get_transcript())
```

## Development

```bash
make help        # show targets
make check       # format, lint, typecheck, test, coverage
make test        # pytest (unit tests only)
```

Integration tests (require model download): `pytest -m integration`

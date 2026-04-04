# Architecture

## Package Layout

```
local-transcribe/
├── local_transcribe/              # Engine (library, no GUI)
│   ├── transcription.py           # Whisper model caching, transcription
│   ├── chunking.py                # SilenceDetector, ChunkManager, trim_silence
│   └── recording.py               # RecordingSession, audio capture
├── local_transcribe_ui/           # Frontend (tkinter GUI + CLI)
│   ├── __main__.py                # Subcommand dispatcher (entry point)
│   ├── recording_controller.py    # RecordingController — embeddable core
│   ├── controller.py              # AppController — thin CLI wrapper
│   ├── gui.py                     # RecordingWindow — tkinter Toplevel
│   ├── config.py                  # Constants, logging setup
│   ├── settings.py                # Settings dataclass + atomic JSON I/O
│   ├── lock.py                    # PID lockfile for single-instance
│   └── protocol.py                # [BEGIN]/[END]/[CANCEL] output markers
└── tests/
```

## Engine (`local_transcribe`)

A pip-installable library with no GUI dependency. Any frontend can import it.

### Module Responsibilities

| Module | Purpose |
|--------|---------|
| `transcription.py` | Whisper model caching, background preload, `transcribe_wav()`, `transcribe_audio()`, WAV I/O |
| `chunking.py` | `SilenceDetector` (silence gap detection), `ChunkManager` (background transcription worker), `trim_silence()` |
| `recording.py` | `RecordingSession` (audio capture via sounddevice, level metering, silence-triggered chunk flushing) |

### Dependency Direction

```
recording.py  →  chunking.py  →  transcription.py
```

Acyclic. Lower-level modules do not import from higher-level ones.

### Key Design Decisions

- **sounddevice is lazy-imported** in `recording.py` via `_sd()` helper so the module can be imported without PortAudio present (CI, testing)
- **Transcript sanitization** is built into `_run_transcription()` — all output is encoding-safe by default
- **All configurable values are parameters** (model_size, device, compute_type, beam_size, silence thresholds, gain) with sensible defaults — no public constants
- **NVIDIA DLLs are auto-loaded on Windows** via `_register_nvidia_dll_paths()` in `transcription.py`, scanning `site-packages/nvidia/*/bin/` before importing ctranslate2
- **Model preload eagerly warms the cache** when model_size/device/compute_type are known at startup
- **Model cache is thread-safe** with `threading.Lock`
- **Preload is thread-safe** with `threading.Lock` on the started flag

## Frontend (`local_transcribe_ui`)

### MVC Architecture

Follows the [tkinter architecture standard](https://github.com/jewzaam/standards/blob/main/python/tkinter/architecture.md):

| Layer | Component | tkinter dependency? |
|-------|-----------|-------------------|
| Model | Engine (`local_transcribe`) | No |
| View | `RecordingWindow` in `gui.py` | Yes |
| Controller | `RecordingController` in `recording_controller.py` | Yes (accepts root) |
| CLI Wrapper | `AppController` in `controller.py` | Yes (owns root) |

`RecordingController` is the embeddable core — accepts an existing `tk.Tk` root, delivers results via callbacks, no `sys.exit()` or `mainloop()`. `AppController` wraps it for standalone CLI use, adding lockfile, stdout protocol, and mainloop ownership.

The engine must not import tkinter. The controller coordinates; windows delegate actions to the controller.

### Window Hierarchy

```
tk.Tk (hidden root — owned by AppController)
└── tk.Toplevel — RecordingWindow (visible popup)
```

`RecordingWindow` uses composition (holds a `Toplevel` reference), not inheritance.

### Subcommand Dispatch

`__main__.py` dispatches to three paths:

| Subcommand | Imports | GUI? | Lock? |
|------------|---------|------|-------|
| `record` | Engine + tkinter + sounddevice | Yes | Yes |
| `transcribe` | Engine only | No | No |
| `devices` | `recording.py` (sounddevice) | No | No |

Deferred imports keep `transcribe` and `devices` fast — no tkinter loaded.

### Settings Persistence

`Settings` dataclass with atomic JSON save (temp-then-rename). Platform-appropriate path:
- Windows: `%APPDATA%/local-transcribe/settings.json`
- Linux: `~/.config/local-transcribe/settings.json`

### PID Locking

`lock.py` uses `O_CREAT|O_EXCL` for atomic lockfile creation. Stale locks (dead PIDs) are cleaned up automatically. Cross-platform PID check (Windows uses `OpenProcess`, POSIX uses `kill(pid, 0)`).

### Config File

`--config PATH` loads a JSON file with defaults for model, compute device/type, and silence detection. When `--config` is set, CLI args for config-managed keys are rejected (exit code 1) — config file wins, no precedence ambiguity. See [Configuration](config.md).

### Output Protocol

The `[BEGIN version=X.Y.Z]` / `[END]` / `[CANCEL]` protocol on stdout allows callers (like Claude Code skills) to parse transcript output reliably.

## Data Flow: GUI Recording

```
User clicks Done
     │
     ▼
RecordingWindow._on_done()
     │ session.stop() + flush + finish(timeout=0)
     ▼
ChunkManager worker thread
     │ trim_silence → transcribe_audio (per chunk)
     ▼
RecordingWindow._poll_transcription()  (via root.after)
     │ is_done() == True
     ▼
RecordingController.on_recording_done()
     │ get_transcript() → on_done callback
     ▼
AppController._on_done()  (CLI wrapper)
     │ emit_begin/end → shutdown
     ▼
stdout: [BEGIN]...[END]
```

During recording, silence detection triggers automatic chunk flushes for background transcription. The level meter and progress bars update via `root.after()` polling. The audio stream is stopped immediately on Done to prevent the progress bar denominator from growing during transcription.

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
│   ├── controller.py              # AppController — GUI lifecycle
│   ├── gui.py                     # RecordingWindow — tkinter Toplevel
│   ├── config.py                  # Constants (colors, fonts, layout)
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
- **All configurable values are parameters** (model_size, device, compute_type, beam_size, gain) with sensible defaults — no public constants
- **Model cache is thread-safe** with `threading.Lock`
- **Preload is thread-safe** with `threading.Lock` on the started flag

## Frontend (`local_transcribe_ui`)

### MVC Architecture

Follows the [tkinter architecture standard](https://github.com/jewzaam/standards/blob/main/python/tkinter/architecture.md):

| Layer | Component | tkinter dependency? |
|-------|-----------|-------------------|
| Model | Engine (`local_transcribe`) | No |
| View | `RecordingWindow` in `gui.py` | Yes |
| Controller | `AppController` in `controller.py` | Yes (owns root) |

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

### Output Protocol

The `[BEGIN version=X.Y.Z]` / `[END]` / `[CANCEL]` protocol on stdout allows callers (like Claude Code skills) to parse transcript output reliably.

## Data Flow: GUI Recording

```
User clicks Done
     │
     ▼
RecordingWindow._on_done()
     │ flush + finish(timeout=0)
     ▼
ChunkManager worker thread
     │ trim_silence → transcribe_audio (per chunk)
     ▼
RecordingWindow._poll_transcription()  (via root.after)
     │ is_done() == True
     ▼
AppController.on_recording_done()
     │ get_transcript() → emit_begin/end → shutdown
     ▼
stdout: [BEGIN]...[END]
```

During recording, silence detection triggers automatic chunk flushes for background transcription. The level meter and progress bars update via `root.after()` polling.

# Plan: local-transcribe — Engine + Frontend

## Goal

Extract the transcription engine from `claude-skill-voice` into a standalone reusable package (`local-transcribe`), then port the tkinter GUI and CLI frontend into the same repo. The engine is usable independently by any consumer; the frontend is one such consumer, bundled here.

## Current State

**Completed (Phase 1-4):**
- Engine extracted into `local_transcribe/` package (recording, chunking, transcription)
- Thread-safe model caching, background preload
- All hardcoded values parameterized (model_size, device, compute_type, beam_size, gain)
- Sanitization built into transcription pipeline
- 83% test coverage, all make check gates pass
- GitHub CI workflows in place

**Still in `claude-skill-voice`:**
- `scripts/voice.py` — tkinter GUI, CLI arg parsing, SKILL.md protocol
- Config persistence (settings.json, window position)
- PID locking (single-instance enforcement)
- `[BEGIN]`/`[END]`/`[CANCEL]` output protocol
- GUI constants (colors, fonts, layout)

## Target Architecture

```
local-transcribe/
├── local_transcribe/          # Engine (no GUI, no CLI)
│   ├── transcription.py       # Whisper model caching, transcription
│   ├── chunking.py            # SilenceDetector, ChunkManager, trim_silence
│   └── recording.py           # RecordingSession, audio capture
├── local_transcribe_ui/       # Frontend (tkinter GUI + CLI)
│   ├── gui.py                 # tkinter popup (record_with_gui)
│   ├── cli.py                 # argparse, main(), SKILL.md protocol
│   ├── config.py              # Config class, settings.json persistence
│   ├── lock.py                # PID lockfile management
│   ├── protocol.py            # [BEGIN]/[END]/[CANCEL] marker emission
│   └── constants.py           # Colors, fonts, layout values
├── tests/
├── scripts/
├── Makefile
└── pyproject.toml
```

The engine (`local_transcribe`) has zero dependency on the frontend. The frontend (`local_transcribe_ui`) imports the engine.

## Separation Boundaries

| Concern | Engine (`local_transcribe`) | Frontend (`local_transcribe_ui`) |
|---------|---------------------------|----------------------------------|
| Audio capture | RecordingSession | No |
| Silence detection | SilenceDetector | Configures thresholds |
| Chunk management | ChunkManager | Calls flush/finish |
| Whisper model | Caching, transcription | No |
| Silence trimming | trim_silence() | No |
| Transcript sanitization | Built into _run_transcription | No |
| tkinter GUI | No | gui.py |
| CLI arg parsing | No | cli.py |
| SKILL.md protocol | No | protocol.py — [BEGIN]/[END]/[CANCEL] |
| Config persistence | No | config.py — settings.json |
| PID locking | No | lock.py |
| Progress display | Provides fraction | Renders bar |

## Phased Approach

### Done

1. ~~Write the plan~~
2. ~~Create new repo (`local-transcribe`)~~
3. ~~Build the engine — extract, refactor, test~~
4. ~~Review and harden — thread safety, parameterization, test coverage~~

### Remaining

5. **Port the frontend** — move GUI, CLI, config, locking, protocol from `claude-skill-voice` into `local_transcribe_ui/`
   - Extract `record_with_gui()` into `gui.py`, wired to `RecordingSession`
   - Extract `main()` into `cli.py`
   - Extract `Config` class into `config.py`
   - Extract lock management into `lock.py`
   - Extract `emit_begin/end/cancel` into `protocol.py`
   - All GUI constants into `constants.py`
   - Add `[project.scripts]` entry point in pyproject.toml for CLI invocation

6. **Add `make run` target** — invokes the CLI for manual testing

7. **Update `claude-skill-voice`** — replace bundled code with `local-transcribe` dependency
   - `SKILL.md` invokes `local-transcribe` CLI instead of `scripts/voice.py`
   - Remove `scripts/whisper.py`, `scripts/chunks.py`, `scripts/voice.py`

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Package name | `local-transcribe` (PyPI), `local_transcribe` (Python) |
| Engine CLI | No — engine is library-only. CLI lives in frontend package. |
| Silence thresholds | Parameterized on constructors with sensible defaults |
| `_sanitize_transcript` location | Engine — built into `_run_transcription`, private |

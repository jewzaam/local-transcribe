# CLI Reference

## Invocation

```bash
local-transcribe <command> [options]
python -m local_transcribe_ui <command> [options]
```

A subcommand is required.

## Commands

### record

Record from microphone with tkinter GUI. Acquires a PID lock to prevent concurrent sessions.

```bash
local-transcribe record [options]
```

| Option | Description |
|--------|-------------|
| `--model MODEL` | Whisper model size: `tiny`, `base`, `small`, `medium`, `large` (default: `small`) |
| `--device ID` | Audio input device ID (default: system default) |
| `--compute-device DEVICE` | Inference device: `cpu`, `cuda`, `auto` (default: `cpu`) |
| `--compute-type TYPE` | Model precision: `int8`, `float16`, `float32` (default: `int8`) |
| `--silence-threshold LEVEL` | Audio level below which is silence, 0.0-1.0 (default: `0.08`) |
| `--silence-duration SECONDS` | Seconds of silence before chunk flush (default: `1.0`) |
| `--min-chunk-seconds SECONDS` | Minimum audio before silence flush triggers (default: `10.0`) |
| `--stream` | Stream transcript chunks to stdout as they complete |
| `--wav-output PATH` | Save recorded audio to a WAV file |
| `--config PATH` | Load defaults from JSON config file (see [Configuration](config.md)) |
| `--debug` | Enable debug logging |
| `--quiet`, `-q` | Suppress non-essential output |
| `--log-file PATH` | Write log output to file |

**Output:** Transcript wrapped in `[BEGIN version=X.Y.Z]` / `[END]` markers on stdout. `[CANCEL]` if the user cancels.

**GUI controls:**
- **Cancel** (Escape) — abort recording
- **Pause/Resume** (Space) — pause/resume, flushes current audio
- **Done** (Enter) — stop recording, wait for transcription to finish

**Examples:**

```bash
local-transcribe record
local-transcribe record --config ~/.config/local-transcribe-config.json
local-transcribe record --model large --compute-device cuda --compute-type float16
local-transcribe record --debug --log-file ~/debug.log
```

### transcribe

Transcribe an existing WAV file. No GUI, no lock, no microphone access.

```bash
local-transcribe transcribe <file> [options]
```

| Option | Description |
|--------|-------------|
| `file` | Path to WAV file (required) |
| `--model MODEL` | Whisper model size (default: `small`) |
| `--compute-device DEVICE` | Inference device: `cpu`, `cuda`, `auto` (default: `cpu`) |
| `--compute-type TYPE` | Model precision: `int8`, `float16`, `float32` (default: `int8`) |
| `--config PATH` | Load defaults from JSON config file (see [Configuration](config.md)) |
| `--debug` | Enable debug logging |
| `--quiet`, `-q` | Suppress non-essential output |
| `--log-file PATH` | Write log output to file |

**Output:** Transcript wrapped in `[BEGIN]` / `[END]` markers on stdout.

**Examples:**

```bash
local-transcribe transcribe meeting.wav
local-transcribe transcribe meeting.wav --model large --compute-device cuda --compute-type float16
local-transcribe transcribe meeting.wav --config ~/.config/local-transcribe-config.json
```

### devices

List available audio input devices.

```bash
local-transcribe devices [options]
```

| Option | Description |
|--------|-------------|
| `--debug` | Enable debug logging |
| `--quiet`, `-q` | Suppress non-essential output |
| `--log-file PATH` | Write log output to file |

**Output:** Device ID and name, one per line.

**Example:**

```bash
$ local-transcribe devices
  0: Microphone (Realtek Audio)
  1: Stereo Mix (Realtek Audio)
```

## Output Protocol

All transcript output uses a line-based protocol for machine parsing:

| Marker | Meaning |
|--------|---------|
| `[BEGIN version=X.Y.Z]` | Start of transcript. Match `[BEGIN` as prefix — ignore attributes |
| `[END]` | End of transcript |
| `[CANCEL]` | User cancelled recording |

Lines between `[BEGIN]` and `[END]` are the transcript text. Empty transcript (no speech) produces `[BEGIN]` immediately followed by `[END]`.

In `--stream` mode, transcript chunks appear between `[BEGIN]` and `[END]` as they complete.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (including cancel) |
| 1 | Error (lock held, device not found, file missing) |

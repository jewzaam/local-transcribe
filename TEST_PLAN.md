# Test Plan

> Testing strategy for local-transcribe.

**Project:** local-transcribe
**Primary functionality:** Chunked local speech-to-text engine using faster-whisper.

## Testing Philosophy

- Unit tests mock hardware (microphone) and heavy dependencies (Whisper model)
- Integration tests (gated by `@pytest.mark.integration`) require a real model download
- Pure-logic components (SilenceDetector, trim_silence) are tested directly with synthetic data
- The audio callback can be tested by calling it directly — no hardware needed

## Test Categories

### Unit Tests

| Module | Function/Class | Test Coverage | Notes |
|--------|---------------|---------------|-------|
| `transcription.py` | `save_wav_to()` | WAV header validation, file creation | Real filesystem |
| `transcription.py` | `_sanitize_transcript()` | ASCII, cp1252, empty | Internal; auto-applied by `_run_transcription` |
| `transcription.py` | `compute_audio_level()` | Zero, mid, max, clamp | Pure arithmetic |
| `transcription.py` | `transcribe_wav()`, `transcribe_audio()` | Mocked model, progress callback | Model mocked via `get_or_create_model` patch |
| `transcription.py` | `get_or_create_model()` | Cache hit, cache miss, size change | `_get_model_class` mocked |
| `chunking.py` | `SilenceDetector` | Trigger, no-trigger, min-chunk, reset, retrigger, buffer | Pure logic |
| `chunking.py` | `trim_silence()` | All silence, speech, padding, all speech | Synthetic int16 arrays |
| `chunking.py` | `ChunkManager` | Bind/flush, fractions, finish, worker loop | Worker tests mock `transcribe_audio` |
| `recording.py` | `RecordingSession` | Init, stop, pause/resume, abort, callback | `sd.InputStream` and device mocked |
| `recording.py` | `_audio_callback` | Chunk append, level, silence detector | Called directly with synthetic data |

### Integration Tests

| Workflow | Components | Test Coverage | Notes |
|----------|------------|---------------|-------|
| WAV transcription | `transcribe_wav` + real model | Silence input | Requires model download, gated by `@pytest.mark.integration` |
| Audio transcription | `transcribe_audio` + real model | Silence input | Same gate |

## Untested Areas

| Area | Reason Not Tested |
|------|-------------------|
| Real microphone recording | Hardware-dependent; `RecordingSession.start()` is tested via mock |
| Model download/caching on disk | Network-dependent; tested via integration marker |
| Thread timing of audio callback | Non-deterministic; callback logic tested synchronously |

## Bug Fix Testing Protocol

All bug fixes to existing functionality **must** follow TDD:

1. Write a failing test that exposes the bug
2. Verify the test fails before implementing the fix
3. Implement the fix
4. Verify the test passes
5. Verify reverting the fix causes the test to fail again
6. Commit test and fix together with issue reference

### Regression Tests

| Issue | Test | Description |
|-------|------|-------------|
| — | — | No regressions yet |

## Coverage Goals

**Target:** 70%+ line coverage (hardware/model paths are inherently harder to unit-test)

**Philosophy:** Coverage measures completeness, not quality. Focus on testing behavior through the public API with meaningful assertions.

## Running Tests

```bash
make test                # unit tests (default, excludes integration)
make coverage            # unit tests with coverage report
pytest -m integration    # integration tests (requires model download)
make check               # full pipeline: format, lint, typecheck, test, coverage
```

## Test Data

Test data is generated programmatically:
- `silence_audio` fixture: 1s of zeros at 16kHz int16
- `speech_audio` fixture: 1s of constant 10000 at 16kHz int16
- `mock_whisper_model` fixture: returns predictable "hello world" segments
- `mock_recording_session` fixture: RecordingSession with mocked device/stream

No static test data files. No Git LFS.

## Changelog

| Date | Change | Rationale |
|------|--------|-----------|
| 2026-03-26 | Initial test plan | Project creation |
